//
//  VideoEncoder.swift
//  StrayScanner
//
//  Created by Kenneth Blomqvist on 12/30/20.
//  Copyright © 2020 Stray Robots. All rights reserved.
//

import Foundation
import ARKit

class VideoEncoder {
    private var rgbWriter: AVAssetWriter?
    private var rgbWriterInput: AVAssetWriterInput?
    private var rgbAdapter: AVAssetWriterInputPixelBufferAdaptor?
    private let timeScale = CMTimeScale(600)
    private let width: CGFloat
    private let height: CGFloat
    private let systemBootedAt: TimeInterval
    private var done: Bool = false
    public var filePath: URL

    init(videoId: UUID, width: CGFloat, height: CGFloat) {
        self.systemBootedAt = ProcessInfo.processInfo.systemUptime
        self.width = width
        self.height = height
        self.filePath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("\(videoId.uuidString).mp4")
        print("File exists: \(FileManager.default.fileExists(atPath: self.filePath.absoluteString))")
        initializeFile(videoId: videoId)
    }

    func finishEncoding() {
        self.doneRecording()
    }

    func addFrame(frame: ARFrame) {
        while !rgbWriterInput!.isReadyForMoreMediaData {
            print("Sleeping.")
            Thread.sleep(until: Date() + TimeInterval(0.05))
        }
        print("encoding frame \(frame.timestamp).")
        encode(frame: frame)
    }

    private func initializeFile(videoId: UUID) {
        do {
            rgbWriter = try AVAssetWriter(outputURL: self.filePath, fileType: .mp4)
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
            rgbAdapter = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: nil)
            if rgbWriter!.canAdd(input) {
                rgbWriter!.add(input)
                rgbWriterInput = input
                rgbWriter!.startWriting()
                rgbWriter!.startSession(atSourceTime: .zero)
            } else {
                print("Can't create writer.")
            }
        } catch let error as NSError {
            print("Creating AVAssetWriter failed. \(error), \(error.userInfo)")
        }
    }

    private func encode(frame: ARFrame) {
        let image: CVPixelBuffer = frame.capturedImage
        let time = CMTime(seconds: frame.timestamp - self.systemBootedAt, preferredTimescale: timeScale)
        rgbAdapter!.append(image, withPresentationTime: time)
    }

    private func doneRecording() {
        if rgbWriter?.status == .failed {
            print("Something went wrong when writing video.")
        } else {
            rgbWriterInput?.markAsFinished()
            rgbWriter?.finishWriting { [weak self] in
                self?.rgbWriter = nil
                self?.rgbWriterInput = nil
                self?.rgbAdapter = nil
            }
        }
    }
}
