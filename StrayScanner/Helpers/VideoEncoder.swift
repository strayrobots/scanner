//
//  VideoEncoder.swift
//  StrayScanner
//
//  Created by Kenneth Blomqvist on 12/30/20.
//  Copyright © 2020 Stray Robots. All rights reserved.
//

import Foundation
import ARKit

struct VideoEncoderInput {
    let buffer: CVPixelBuffer
    let time: TimeInterval // Relative to boot time.
}

class VideoEncoder {
    enum EncodingStatus {
        case allGood
        case error
    }
    
    private var videoWriter: AVAssetWriter?
    private var videoWriterInput: AVAssetWriterInput?
    private var videoAdapter: AVAssetWriterInputPixelBufferAdaptor?
    // Presentation timestamps come from ARFrame.timestamp, so use a fine time scale
    // (the standard 90 kHz video clock) instead of assuming a fixed frame rate.
    private let timeScale = CMTimeScale(90_000)
    public let width: CGFloat
    public let height: CGFloat
    private var done: Bool = false
    private var firstFrameTime: TimeInterval?
    private var previousPresentationTime: CMTime?
    public var filePath: URL
    public var status: EncodingStatus = EncodingStatus.allGood

    init(file: URL, width: CGFloat, height: CGFloat) {
        self.filePath = file
        self.width = width
        self.height = height
        initializeFile()
    }

    func finishEncoding() {
        self.doneRecording()
    }

    // How often add() had to wait for the encoder, for diagnosing dropped frames.
    public private(set) var waitCount: Int = 0

    // Returns without encoding if the writer is missing or has failed, so the
    // caller's queue (and wrapUp, which waits on it) never blocks forever.
    func add(frame: VideoEncoderInput) {
        guard let writer = videoWriter, let input = videoWriterInput, videoAdapter != nil else {
            status = .error
            return
        }
        while !input.isReadyForMoreMediaData {
            guard writer.status == .writing else {
                print("Video writer stopped writing. \(writer.error?.localizedDescription ?? "Unknown error.")")
                status = .error
                return
            }
            waitCount += 1
            Thread.sleep(until: Date() + TimeInterval(0.005))
        }
        encode(frame: frame)
    }

    static func outputSettings(width: CGFloat, height: CGFloat) -> [String: Any] {
        return [
            AVVideoCodecKey: AVVideoCodecType.hevc,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height
        ]
    }

    private static let warmUpQueue = DispatchQueue(label: "videoEncoderWarmUp", qos: .utility)

    // Encodes one blank frame at the given resolution into a throwaway file.
    // Creating the first HEVC encoder for a resolution is slow (it caused a
    // ~1 s stall at the start of 4K recordings). Doing it once ahead of time,
    // while the user is still framing the shot, makes the real encoder start faster.
    static func warmUp(width: CGFloat, height: CGFloat) {
        warmUpQueue.async {
            let started = Date()
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("warmup-\(UUID().uuidString).mp4")
            defer { try? FileManager.default.removeItem(at: url) }
            guard let writer = try? AVAssetWriter(outputURL: url, fileType: .mp4) else { return }
            let input = AVAssetWriterInput(mediaType: .video, outputSettings: outputSettings(width: width, height: height))
            input.expectsMediaDataInRealTime = true
            let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: nil)
            guard writer.canAdd(input) else { return }
            writer.add(input)
            var buffer: CVPixelBuffer?
            let attributes = [kCVPixelBufferIOSurfacePropertiesKey: [:]] as CFDictionary
            let result = CVPixelBufferCreate(nil, Int(width), Int(height), kCVPixelFormatType_420YpCbCr8BiPlanarFullRange, attributes, &buffer)
            guard result == kCVReturnSuccess, let pixelBuffer = buffer else {
                print("Video encoder warm-up failed: could not create pixel buffer (\(result)).")
                return
            }
            guard writer.startWriting() else {
                print("Video encoder warm-up failed: \(writer.error?.localizedDescription ?? "Unknown error.")")
                writer.cancelWriting()
                return
            }
            writer.startSession(atSourceTime: .zero)
            // Give up if the writer fails or never becomes ready. The queue is
            // serial, so spinning here would block every later warm-up.
            let deadline = Date() + TimeInterval(5.0)
            while !input.isReadyForMoreMediaData {
                guard writer.status == .writing, Date() < deadline else {
                    print("Video encoder warm-up failed: \(writer.error?.localizedDescription ?? "Timed out.")")
                    writer.cancelWriting()
                    return
                }
                Thread.sleep(forTimeInterval: 0.005)
            }
            adaptor.append(pixelBuffer, withPresentationTime: .zero)
            input.markAsFinished()
            let done = DispatchSemaphore(value: 0)
            writer.finishWriting { done.signal() }
            done.wait()
            print("Warmed up \(Int(width))x\(Int(height)) video encoder in \(String(format: "%.0f", Date().timeIntervalSince(started) * 1000)) ms.")
        }
    }

    private func initializeFile() {
        do {
            videoWriter = try AVAssetWriter(outputURL: self.filePath, fileType: .mp4)
            let input = AVAssetWriterInput(mediaType: .video, outputSettings: VideoEncoder.outputSettings(width: self.width, height: self.height))
            input.expectsMediaDataInRealTime = true
            input.mediaTimeScale = timeScale
            input.performsMultiPassEncodingIfSupported = false
            videoAdapter = createVideoAdapter(input)
            if videoWriter!.canAdd(input) {
                videoWriter!.add(input)
                videoWriterInput = input
                if videoWriter!.startWriting() {
                    videoWriter!.startSession(atSourceTime: .zero)
                } else {
                    print("Starting AVAssetWriter failed. \(videoWriter!.error?.localizedDescription ?? "Unknown error.")")
                    status = .error
                }
            } else {
                print("Can't create writer.")
                status = .error
            }
        } catch let error as NSError {
            print("Creating AVAssetWriter failed. \(error), \(error.userInfo)")
            status = .error
        }
    }

    private func encode(frame: VideoEncoderInput) {
        let image: CVPixelBuffer = frame.buffer
        let time = presentationTime(for: frame.time)
        guard let adapter = videoAdapter else {
            status = .error
            return
        }
        let success = adapter.append(image, withPresentationTime: time)
        if !success {
            print("Pixel buffer could not be appended. \(videoWriter?.error?.localizedDescription ?? "Unknown error.")")
            status = .error
        }
    }

    // The first frame lands at t = 0 (the writer session start), later frames at
    // their capture time relative to it. This keeps playback speed correct for any
    // capture rate (60 or 30 fps) and any frame skipping.
    // Every frame must be appended, because rgb.mp4 frame i corresponds to
    // depth/i.png and odometry row i. So if rounding ever produced a timestamp that
    // isn't strictly increasing, nudge it forward by one tick instead of dropping it.
    private func presentationTime(for timestamp: TimeInterval) -> CMTime {
        if firstFrameTime == nil {
            firstFrameTime = timestamp
        }
        var time = CMTime(seconds: timestamp - firstFrameTime!, preferredTimescale: timeScale)
        if let previous = previousPresentationTime, time <= previous {
            time = previous + CMTime(value: 1, timescale: timeScale)
        }
        previousPresentationTime = time
        return time
    }

    private func doneRecording() {
        guard let writer = videoWriter else {
            self.status = .error
            return
        }
        if writer.status != .writing {
            // Failed (or never started): finishing would not produce a usable file.
            print("Something went wrong when writing video. \(writer.error?.localizedDescription ?? "Unknown error.")")
            self.status = .error
        } else {
            videoWriterInput?.markAsFinished()
            videoWriter?.finishWriting { [weak self] in
                self?.videoWriter = nil
                self?.videoWriterInput = nil
                self?.videoAdapter = nil
            }
        }
    }

    private func createVideoAdapter(_ input: AVAssetWriterInput) -> AVAssetWriterInputPixelBufferAdaptor {
        return AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: nil)
    }
}
