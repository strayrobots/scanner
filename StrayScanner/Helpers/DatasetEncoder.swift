//
//  DatasetEncoder.swift
//  StrayScanner
//
//  Created by Kenneth Blomqvist on 1/2/21.
//  Copyright © 2021 Stray Robots. All rights reserved.
//

import Foundation
import ARKit
import CryptoKit
import CoreMotion

class DatasetEncoder {
    enum Status {
        case allGood
        case videoEncodingError
        case directoryCreationError
    }
    private let rgbEncoder: VideoEncoder
    private let depthEncoder: DepthEncoder
    private let confidenceEncoder: ConfidenceEncoder
    private let datasetDirectory: URL
    private let odometryEncoder: OdometryEncoder
    private let imuEncoder: IMUEncoder
    private let distortionEncoder: DistortionEncoder
    private var lastIntrinsics: simd_float3x3?
    private var dispatchGroup = DispatchGroup()
    private var currentFrame: Int = -1
    private var savedFrames: Int = 0
    private let videoFormatDescription: String
    private let frameInterval: Int // Only save every frameInterval-th frame.
    // Limits how many camera images wait for the video encoder. Each one holds a
    // buffer from ARKit's small pool, and ARKit stalls if the app keeps too many.
    // Only the video holds ARKit buffers: depth and confidence are copied out right away.
    private let videoSemaphore = DispatchSemaphore(value: 3)
    private let videoQueue = DispatchQueue(label: "videoEncoderQueue", qos: .userInitiated)
    private let depthQueue = DispatchQueue(label: "depthEncoderQueue", qos: .userInitiated)
    private let confidenceQueue = DispatchQueue(label: "confidenceEncoderQueue", qos: .userInitiated)
    // Odometry and distortion files are written here, not on the ARSession delegate
    // (main) thread: if storage stalls during a write, ARKit can't deliver frames.
    private let metadataQueue = DispatchQueue(label: "metadataEncoderQueue", qos: .userInitiated)
    private let stats = EncodingStats()
    public let id: UUID
    public let rgbFilePath: URL // Relative to app document directory.
    public let depthFilePath: URL // Relative to app document directory.
    public let cameraMatrixPath: URL
    public let odometryPath: URL
    public let imuPath: URL
    public var status = Status.allGood
    
    private var latestAccelerometerData: (timestamp: Double, data: simd_double3)?
    private var latestGyroscopeData: (timestamp: Double, data: simd_double3)?


    // Capture time (CACurrentMediaTime clock) at which record was pressed. Frames and
    // IMU samples captured earlier are ignored, so every stream starts at this moment.
    private let startTime: TimeInterval

    init(arConfiguration: ARWorldTrackingConfiguration, fpsDivider: Int = 1, startTime: TimeInterval) {
        self.frameInterval = fpsDivider
        self.startTime = startTime
        
        let videoFormat = arConfiguration.videoFormat
        let width = videoFormat.imageResolution.width
        let height = videoFormat.imageResolution.height
        self.videoFormatDescription = "\(Int(width))x\(Int(height)) @ \(videoFormat.framesPerSecond) fps, keeping every \(fpsDivider). frame"
        var theId: UUID = UUID()
        datasetDirectory = DatasetEncoder.createDirectory(id: &theId)
        self.id = theId
        self.rgbFilePath = datasetDirectory.appendingPathComponent("rgb.mp4")
        self.rgbEncoder = VideoEncoder(file: self.rgbFilePath, width: width, height: height)
        self.depthFilePath = datasetDirectory.appendingPathComponent("depth", isDirectory: true)
        self.depthEncoder = DepthEncoder(outDirectory: self.depthFilePath)
        let confidenceFilePath = datasetDirectory.appendingPathComponent("confidence", isDirectory: true)
        self.confidenceEncoder = ConfidenceEncoder(outDirectory: confidenceFilePath)
        self.cameraMatrixPath = datasetDirectory.appendingPathComponent("camera_matrix.csv", isDirectory: false)
        self.odometryPath = datasetDirectory.appendingPathComponent("odometry.csv", isDirectory: false)
        self.odometryEncoder = OdometryEncoder(url: self.odometryPath)
        self.imuPath = datasetDirectory.appendingPathComponent("imu.csv", isDirectory: false)
        self.imuEncoder = IMUEncoder(url: self.imuPath)
        self.distortionEncoder = DistortionEncoder(datasetDirectory: datasetDirectory)
    }

    func add(frame: ARFrame) {
        // ARKit delivers frames with ~100 ms delay, so the first frames to arrive after
        // record was pressed were captured before it. Skip those.
        if frame.timestamp < startTime {
            stats.skippedEarlyFrame()
            return
        }
        let addStarted = CACurrentMediaTime()
        defer { stats.delegate.add(CACurrentMediaTime() - addStarted, frame: currentFrame) }
        currentFrame = currentFrame + 1
        // ARFrame.timestamp and CACurrentMediaTime use the same clock, so this is how
        // long the frame waited before reaching us. It grows if the main thread is busy.
        stats.receivedFrame(timestamp: frame.timestamp, latency: addStarted - frame.timestamp)
        if (currentFrame % frameInterval != 0) {
            return
        }
        // Drop the whole frame (video, depth and odometry together, so frame numbers
        // stay in sync) if the video encoder is backed up.
        guard videoSemaphore.wait(timeout: .now()) == .success else {
            stats.droppedFrame()
            return
        }
        let frameNumber: Int = savedFrames
        savedFrames = savedFrames + 1

        // Copy what odometry and distortion need, so the ARFrame isn't kept alive.
        let pose = OdometryEncoder.Pose(frame: frame)
        let lookupTable = frame.capturedDepthData?.cameraCalibrationData?.lensDistortionLookupTable
        lastIntrinsics = frame.camera.intrinsics
        dispatchGroup.enter()
        metadataQueue.async {
            defer { self.dispatchGroup.leave() }
            self.odometryEncoder.add(pose: pose, currentFrame: frameNumber)
            if let lookupTable = lookupTable {
                self.distortionEncoder.add(lookupTable: lookupTable, currentFrame: frameNumber)
            }
        }

        let depth = frame.sceneDepth.map { PlaneCopy($0.depthMap, bytesPerPixel: 4) }
        let confidence = frame.sceneDepth?.confidenceMap.map { PlaneCopy($0, bytesPerPixel: 1) }
        let videoInput = VideoEncoderInput(buffer: frame.capturedImage, time: frame.timestamp)

        dispatchGroup.enter()
        videoQueue.async {
            defer {
                self.videoSemaphore.signal()
                self.dispatchGroup.leave()
            }
            let started = CACurrentMediaTime()
            self.rgbEncoder.add(frame: videoInput)
            self.stats.video.add(CACurrentMediaTime() - started, frame: frameNumber)
        }

        dispatchGroup.enter()
        depthQueue.async {
            defer { self.dispatchGroup.leave() }
            let started = CACurrentMediaTime()
            if let depth = depth {
                self.depthEncoder.encodeFrame(frame: depth, frameNumber: frameNumber)
            } else {
                self.stats.missingDepth(frameNumber)
                print("warning: scene depth missing for frame \(frameNumber).")
            }
            self.stats.depth.add(CACurrentMediaTime() - started, frame: frameNumber)
        }

        // Depth and confidence PNGs are encoded in parallel.
        if let confidence = confidence {
            dispatchGroup.enter()
            confidenceQueue.async {
                defer { self.dispatchGroup.leave() }
                let started = CACurrentMediaTime()
                self.confidenceEncoder.encodeFrame(frame: confidence, frameNumber: frameNumber)
                self.stats.confidence.add(CACurrentMediaTime() - started, frame: frameNumber)
            }
        } else if depth != nil {
            print("warning: confidence map missing.")
        }
    }
    
   func addRawAccelerometer(data: CMAccelerometerData) {
        if data.timestamp < startTime { return }
        let acceleration = simd_double3(data.acceleration.x, data.acceleration.y, data.acceleration.z)
        latestAccelerometerData = (timestamp: data.timestamp, data: acceleration)
        tryWritingIMUData()
    }

    func addRawGyroscope(data: CMGyroData) {
        if data.timestamp < startTime { return }
        let rotationRate = simd_double3(data.rotationRate.x, data.rotationRate.y, data.rotationRate.z)
        latestGyroscopeData = (timestamp: data.timestamp, data: rotationRate)
        tryWritingIMUData()
    }

    private func tryWritingIMUData() {
        guard
            let accelerometer = latestAccelerometerData,
            let gyroscope = latestGyroscopeData
        else {
            return
        }

        // Write the row to the CSV with the most recent timestamp
        let timestamp = max(accelerometer.timestamp, gyroscope.timestamp)
        imuEncoder.add(
            timestamp: timestamp,
            linear: accelerometer.data,
            angular: gyroscope.data
        )

        // Clear the buffers after writing
        latestAccelerometerData = nil
        latestGyroscopeData = nil
    }

    func wrapUp() {
        dispatchGroup.wait()
        print(stats.summary(format: videoFormatDescription, savedFrames: savedFrames, videoWaits: rgbEncoder.waitCount))
        self.rgbEncoder.finishEncoding()
        self.imuEncoder.done()
        self.odometryEncoder.done()
        self.distortionEncoder.done()
        writeIntrinsics()
        // Any failing encoder fails the whole recording. RecordSessionViewController
        // only saves recordings whose status is .allGood.
        status = .allGood
        if self.rgbEncoder.status == .error {
            status = .videoEncodingError
            print("Something went wrong encoding video.")
        }
        if self.depthEncoder.status == .frameEncodingError {
            status = .videoEncodingError
            print("Something went wrong encoding depth.")
        }
        if self.confidenceEncoder.status == .encodingError {
            status = .videoEncodingError
            print("Something went wrong encoding confidence values.")
        }
    }

    private func writeIntrinsics() {
        if let cameraMatrix = lastIntrinsics {
            let rows = cameraMatrix.transpose.columns
            var csv: [String] = []
            for row in [rows.0, rows.1, rows.2] {
                let csvLine = "\(row.x), \(row.y), \(row.z)"
                csv.append(csvLine)
            }
            let contents = csv.joined(separator: "\n")
            do {
                try contents.write(to: self.cameraMatrixPath, atomically: true, encoding: String.Encoding.utf8)
            } catch let error {
                print("Could not write camera matrix. \(error.localizedDescription)")
            }
        }
    }

    static private func createDirectory(id: inout UUID) -> URL {
        let directoryId = hashUUID(id: id)
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        var directory = URL(fileURLWithPath: directoryId, relativeTo: url)
        if FileManager.default.fileExists(atPath: directory.absoluteString) {
            // Just in case the first 5 characters clash, try again.
            id = UUID()
            directory = DatasetEncoder.createDirectory(id: &id)
        }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
        } catch let error as NSError {
            print("Error creating directory. \(error), \(error.userInfo)")
        }
        return directory
    }

    static private func hashUUID(id: UUID) -> String {
        var hasher: SHA256 = SHA256()
        hasher.update(data: id.uuidString.data(using: .ascii)!)
        let digest = hasher.finalize()
        var string = ""
        digest.makeIterator().prefix(5).forEach { (byte: UInt8) in
            string += String(format: "%02x", byte)
        }
        print("Hash: \(string)")
        return string
    }
}

// Timing and drop counters printed when a recording ends, to find out whether
// dropped frames come from ARKit, the video encoder or the PNG writing.
// Each counter is only touched from one thread (ARSession delegate, video queue
// or depth queue) and read after all of them have finished.
class EncodingStats {
    class Timer {
        private(set) var count = 0
        private(set) var total: TimeInterval = 0
        private(set) var first: TimeInterval = 0
        private(set) var max: TimeInterval = 0
        private(set) var maxFrame = 0
        func add(_ duration: TimeInterval, frame: Int) {
            if count == 0 { first = duration }
            count += 1
            total += duration
            if duration > max {
                max = duration
                maxFrame = frame
            }
        }
        var description: String {
            guard count > 0 else { return "n/a" }
            return String(format: "first %.0f ms, mean %.1f ms, max %.0f ms (frame %d)", first * 1000, total / Double(count) * 1000, max * 1000, maxFrame)
        }
    }
    let video = Timer()
    let depth = Timer()
    let confidence = Timer()
    let delegate = Timer() // Time spent in DatasetEncoder.add on the main thread.
    let latency = Timer()  // Time from capture until the frame reached DatasetEncoder.add.
    private var received = 0
    private var dropped = 0
    private var missingDepthFrames: [Int] = []
    private var firstTimestamp: TimeInterval?
    private var lastTimestamp: TimeInterval = 0
    private var previousTimestamp: TimeInterval?
    private var intervals: [TimeInterval] = []

    private var gaps: [(at: TimeInterval, length: TimeInterval)] = []

    func receivedFrame(timestamp: TimeInterval, latency delay: TimeInterval) {
        latency.add(delay, frame: received)
        if let previous = previousTimestamp, let first = firstTimestamp, timestamp - previous > 0.05 {
            gaps.append((at: previous - first, length: timestamp - previous))
        }
        received += 1
        if firstTimestamp == nil { firstTimestamp = timestamp }
        if let previous = previousTimestamp { intervals.append(timestamp - previous) }
        previousTimestamp = timestamp
        lastTimestamp = timestamp
    }
    func droppedFrame() { dropped += 1 }
    private var skippedEarly = 0
    func skippedEarlyFrame() { skippedEarly += 1 }
    func missingDepth(_ frameNumber: Int) { missingDepthFrames.append(frameNumber) }

    func summary(format: String, savedFrames: Int, videoWaits: Int) -> String {
        let duration = lastTimestamp - (firstTimestamp ?? lastTimestamp)
        let arkitFps = duration > 0 ? Double(received - 1) / duration : 0
        let median = intervals.sorted()[safe: intervals.count / 2] ?? 0
        let gapCount = intervals.filter { $0 > median * 1.5 }.count
        let gapList = gaps.map { String(format: "%.0f ms at %.2f s", $0.length * 1000, $0.at) }.joined(separator: ", ")
        return """
        Recording summary: \(format).
          ARKit delivered \(received) frames in \(String(format: "%.2f", duration)) s (\(String(format: "%.1f", arkitFps)) fps, \(gapCount) gaps between ARKit frames).
          Gaps over 50 ms: \(gapList.isEmpty ? "none" : gapList).
          Delivery latency (capture -> app): \(latency.description).
          Main thread time per frame: \(delegate.description).
          Skipped \(skippedEarly) frames captured before record was pressed.
          Saved \(savedFrames), dropped \(dropped) because the video encoder was backed up.
          Video append: \(video.description), waited for encoder \(videoWaits) times.
          Depth PNG: \(depth.description).
          Confidence PNG: \(confidence.description).
          Frames without scene depth: \(missingDepthFrames.isEmpty ? "none" : missingDepthFrames.map(String.init).joined(separator: ", ")).
        """
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
