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
    private let timeScale = CMTimeScale(600)
    public let width: CGFloat
    public let height: CGFloat
    private let systemBootedAt: TimeInterval
    private var done: Bool = false
    private let depth: Bool
    public var filePath: URL
    public var status: EncodingStatus = EncodingStatus.allGood

    init(file: URL, width: CGFloat, height: CGFloat, depth: Bool) {
        self.depth = depth
        self.systemBootedAt = ProcessInfo.processInfo.systemUptime
        self.filePath = file
        self.width = width
        self.height = height
        initializeFile()
    }

    func finishEncoding() {
        self.doneRecording()
    }

    func addFrame(frame: VideoEncoderInput) {
        while !videoWriterInput!.isReadyForMoreMediaData {
            print("Sleeping.")
            Thread.sleep(until: Date() + TimeInterval(0.01))
        }
        encode(frame: frame)
    }

    private func initializeFile() {
        do {
            videoWriter = try AVAssetWriter(outputURL: self.filePath, fileType: .mp4)
            let settings: [String : Any] = [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: self.width,
                AVVideoHeightKey: self.height,
                //AVVideoQualityKey: NSNumber(1.0)
            ]
            let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
            input.expectsMediaDataInRealTime = true
            input.mediaTimeScale = timeScale
            input.transform = CGAffineTransform(rotationAngle: .pi/2) // Portrait mode.
            videoAdapter = createVideoAdapter(input)
            if videoWriter!.canAdd(input) {
                videoWriter!.add(input)
                videoWriterInput = input
                videoWriter!.startWriting()
                videoWriter!.startSession(atSourceTime: .zero)
            } else {
                print("Can't create writer.")
            }
        } catch let error as NSError {
            print("Creating AVAssetWriter failed. \(error), \(error.userInfo)")
        }
    }

    private func encode(frame: VideoEncoderInput) {
        let image: CVPixelBuffer = frame.buffer
        let time = CMTime(seconds: frame.time - self.systemBootedAt, preferredTimescale: timeScale)
        print("Time: \(frame.time)")
        let success = videoAdapter!.append(image, withPresentationTime: time)
        if !success {
            print("Pixel buffer could not be appended. \(videoWriter!.error!.localizedDescription)")
        }
    }

    private func doneRecording() {
        if videoWriter?.status == .failed {
            let error = videoWriter!.error
            print("Something went wrong when writing video. \(error!.localizedDescription)")
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
        if self.depth {
            let attributes: [String : Any] = [String(kCVPixelBufferPixelFormatTypeKey) : Int(kCVPixelFormatType_32ARGB),
                String(kCVPixelBufferWidthKey) : Float(width),
                String(kCVPixelBufferHeightKey) : Float(height)]
            return AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: attributes)
        } else {
            return AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: nil)
        }
    }
}
