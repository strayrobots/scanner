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
    private var lock: NSLock = NSLock()
    private var queue: [ARFrame?] = []
    private var rgbWriter: AVAssetWriter?
    private var rgbWriterInput: AVAssetWriterInput?
    private var rgbAdapter: AVAssetWriterInputPixelBufferAdaptor?
    private let timeScale = CMTimeScale(60)
    private let width: CGFloat
    private let height: CGFloat
    public var filePath: URL

    init(recordStart: Date, videoId: UUID, width: CGFloat, height: CGFloat) {
        self.width = width
        self.height = height
        self.filePath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("\(videoId.uuidString).mp4")
        initializeFile(videoId: videoId)
        DispatchQueue.global(qos: .utility).async {
            self.runLoop()
        }
    }

    func addFrame(frame: ARFrame) {
        lock.lock()
        queue.append(frame)
        lock.unlock()
    }

    private func initializeFile(videoId: UUID) {
        do {
            rgbWriter = try AVAssetWriter(url: self.filePath, fileType: .mp4)
            let settings: [String : Any] = [
                AVVideoCodecKey: AVVideoCodecType.hevc,
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
            } else {
                print("Can't create writer.")
            }
        } catch let error as NSError {
            print("Creating AVAssetWriter failed. \(error), \(error.userInfo)")
        }
    }

    private func runLoop() {
        if rgbWriterInput == nil { return }
        while true {
            if !rgbWriterInput!.isReadyForMoreMediaData || !lock.try() {
                Thread.sleep(until: Date() + TimeInterval(0.05))
            } else {
                let frame = queue.removeFirst()
                lock.unlock()
                if frame == nil {
                    // Poison pill. We are done. Close up the session.
                    doneRecording()
                    return
                } else {
                    self.encode(frame: frame!)
                }
            }
        }
    }

    private func encode(frame: ARFrame) {
        let image: CVPixelBuffer = frame.capturedImage
        let time = CMTime(seconds: frame.timestamp, preferredTimescale: timeScale)
        rgbAdapter?.append(image, withPresentationTime: time)
    }

    private func doneRecording() {
        if rgbWriter?.status == .failed {
            print("Something went wrong writing video.")
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
