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
    private let timeScale = CMTimeScale(60)
    public let width: CGFloat
    public let height: CGFloat
    private let systemBootedAt: TimeInterval
    private var done: Bool = false
    private var previousFrame: Int = -1
    public var filePath: URL
    public var status: EncodingStatus = EncodingStatus.allGood

    init(file: URL, width: CGFloat, height: CGFloat) {
        self.systemBootedAt = ProcessInfo.processInfo.systemUptime
        self.filePath = file
        self.width = width
        self.height = height
        initializeFile()
    }

    func finishEncoding() {
        self.doneRecording()
    }

    func add(frame: VideoEncoderInput, currentFrame: Int) {
        previousFrame = currentFrame
        while !videoWriterInput!.isReadyForMoreMediaData {
            print("Sleeping.")
            Thread.sleep(until: Date() + TimeInterval(0.01))
        }
        encode(frame: frame, frameNumber: currentFrame)
    }

    private func initializeFile() {
        do {
            videoWriter = try AVAssetWriter(outputURL: self.filePath, fileType: .mp4)
            let settings: [String : Any] = [
                AVVideoCodecKey: AVVideoCodecType.hevc,
                AVVideoWidthKey: self.width,
                AVVideoHeightKey: self.height
            ]
            let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
            input.expectsMediaDataInRealTime = true
            input.mediaTimeScale = timeScale
            input.performsMultiPassEncodingIfSupported = false
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

    private func encode(frame: VideoEncoderInput, frameNumber: Int) {
        let image: CVPixelBuffer = frame.buffer
        let time = CMTime(value: Int64(frameNumber), timescale: timeScale)
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
        return AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: nil)
    }
}
