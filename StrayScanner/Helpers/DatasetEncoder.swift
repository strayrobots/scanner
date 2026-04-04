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
import UIKit

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
    private var lastFrame: ARFrame?
    private var dispatchGroup = DispatchGroup()
    private var currentFrame: Int = -1
    private var savedFrames: Int = 0
    private let frameInterval: Int // Only save every frameInterval-th frame.
    public let id: UUID
    public let rgbFilePath: URL // Relative to app document directory.
    public let depthFilePath: URL // Relative to app document directory.
    public let cameraMatrixPath: URL
    public let odometryPath: URL
    public let imuPath: URL
    public var status = Status.allGood
    private let queue: DispatchQueue
    
    private var latestAccelerometerData: (timestamp: Double, data: simd_double3)?
    private var latestGyroscopeData: (timestamp: Double, data: simd_double3)?
    
    // Adaptive mode properties
    private let adaptiveModeEnabled: Bool
    private let positionThreshold: Float
    private let angleThresholdCos: Float // Cosine of angle threshold for efficient comparison
    private var lastSavedTransform: simd_float4x4?
    private let hapticGenerator = UIImpactFeedbackGenerator(style: .light)


    init(arConfiguration: ARWorldTrackingConfiguration, fpsDivider: Int = 1) {
        self.frameInterval = fpsDivider
        self.queue = DispatchQueue(label: "encoderQueue")
        
        // Check if we're in adaptive mode (indicated by the FPS button selection)
        let currentFpsSetting = UserDefaults.standard.integer(forKey: FpsUserDefaultsKey)
        self.adaptiveModeEnabled = (currentFpsSetting == AdaptiveModeIndex)
        
        // Load adaptive mode thresholds with defaults
        let posThreshold = UserDefaults.standard.double(forKey: AdaptiveThresholdPositionKey)
        let angleThresholdDegrees = UserDefaults.standard.double(forKey: AdaptiveThresholdAngleKey)
        self.positionThreshold = Float(posThreshold > 0 ? posThreshold : DefaultAdaptiveThresholdPosition)
        
        // Convert angle threshold to cosine for efficient comparison
        let angleThresholdRadians = Float(angleThresholdDegrees > 0 ? angleThresholdDegrees : DefaultAdaptiveThresholdAngle) * Float.pi / 180.0
        self.angleThresholdCos = cos(angleThresholdRadians) // Direct angle for forward vector comparison
        
        // Prepare haptic generator
        if self.adaptiveModeEnabled {
            hapticGenerator.prepare()
            let angleDegreesForDebug = acos(self.angleThresholdCos) * 180.0 / Float.pi
            print("Adaptive mode enabled: pos threshold=\(self.positionThreshold*100)cm, angle threshold=\(angleDegreesForDebug)° (forward vector)")
        } else {
            print("Adaptive mode disabled")
        }
        
        let width = arConfiguration.videoFormat.imageResolution.width
        let height = arConfiguration.videoFormat.imageResolution.height
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
    }

    func add(frame: ARFrame) {
        let totalFrames: Int = currentFrame
        let frameNumber: Int = savedFrames
        currentFrame = currentFrame + 1
        
        // Check if we should skip this frame based on frame interval
        if (currentFrame % frameInterval != 0) {
            return
        }
        
        // If adaptive mode is enabled, check if pose has changed significantly
        if adaptiveModeEnabled {
            let currentTransform = frame.camera.transform
            
            if let lastTransform = lastSavedTransform {
                // Calculate position change
                let lastPos = simd_float3(lastTransform.columns.3.x, lastTransform.columns.3.y, lastTransform.columns.3.z)
                let currentPos = simd_float3(currentTransform.columns.3.x, currentTransform.columns.3.y, currentTransform.columns.3.z)
                let positionDelta = simd_distance(lastPos, currentPos)
                
                // Calculate forward vector dot product for rotation comparison
                // Forward is -Z in ARKit's coordinate system
                let lastForward = -simd_float3(lastTransform.columns.2.x, lastTransform.columns.2.y, lastTransform.columns.2.z)
                let currentForward = -simd_float3(currentTransform.columns.2.x, currentTransform.columns.2.y, currentTransform.columns.2.z)
                let dotProduct = simd_dot(lastForward, currentForward)
                
                // Debug logging (remove in production)
//                if adaptiveModeEnabled {
//                    let angleDelta = acos(min(dotProduct, 1.0)) * 180.0 / Float.pi
//                    let angleThresholdDegrees = acos(angleThresholdCos) * 180.0 / Float.pi
//                    print("Adaptive mode: pos=\(positionDelta*100)cm, angle=\(angleDelta)°, thresholds: pos=\(positionThreshold*100)cm, angle=\(angleThresholdDegrees)°")
//                }
                
                // Skip frame if changes are below thresholds
                // Note: dotProduct > angleThresholdCos means angle < threshold (cosine decreases as angle increases)
                if positionDelta < positionThreshold && dotProduct > angleThresholdCos {
                    return
                }
            }
            
            // Update last saved transform
            lastSavedTransform = currentTransform
            
            // Trigger haptic feedback for adaptive mode capture
            DispatchQueue.main.async {
                self.hapticGenerator.impactOccurred()
            }
        }
        
        // Extract what we need from the frame before async dispatch
        let capturedImage = frame.capturedImage
        let sceneDepth = frame.sceneDepth
        let frameTimestamp = frame.timestamp
        let frameTransform = frame.camera.transform
        
        dispatchGroup.enter()
        queue.async { [weak self] in
            defer {
                // Always balance enter/leave, even if self is nil
                self?.dispatchGroup.leave()
            }
            
            guard let self = self else { return }
            
            if let sceneDepth = sceneDepth {
                self.depthEncoder.encodeFrame(frame: sceneDepth.depthMap, frameNumber: frameNumber)
                if let confidence = sceneDepth.confidenceMap {
                    self.confidenceEncoder.encodeFrame(frame: confidence, frameNumber: frameNumber)
                } else {
                    print("warning: confidence map missing.")
                }
            } else {
                print("warning: scene depth missing.")
            }
            
            self.rgbEncoder.add(frame: VideoEncoderInput(buffer: capturedImage, time: frameTimestamp), currentFrame: frameNumber)
            self.odometryEncoder.add(frame: frame, currentFrame: frameNumber)
            self.lastFrame = frame
        }
        savedFrames = savedFrames + 1
    }
    
   func addRawAccelerometer(data: CMAccelerometerData) {
        let acceleration = simd_double3(data.acceleration.x, data.acceleration.y, data.acceleration.z)
        latestAccelerometerData = (timestamp: data.timestamp, data: acceleration)
        tryWritingIMUData()
    }

    func addRawGyroscope(data: CMGyroData) {
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
        self.rgbEncoder.finishEncoding()
        self.imuEncoder.done()
        self.odometryEncoder.done()
        writeIntrinsics()
        switch self.rgbEncoder.status {
            case .allGood:
                status = .allGood
            case .error:
                status = .videoEncodingError
        }
        switch self.depthEncoder.status {
            case .allGood:
                status = .allGood
            case .frameEncodingError:
                status = .videoEncodingError
                print("Something went wrong encoding depth.")
        }
        switch self.confidenceEncoder.status {
            case .allGood:
                status = .allGood
            case .encodingError:
                status = .videoEncodingError
                print("Something went wrong encoding confidence values.")
        }
    }

    private func writeIntrinsics() {
        if let cameraMatrix = lastFrame?.camera.intrinsics {
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
