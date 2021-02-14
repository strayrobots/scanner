//
//  DepthEncoder.swift
//  StrayScanner
//
//  Created by Kenneth Blomqvist on 1/24/21.
//  Copyright © 2021 Stray Robots. All rights reserved.
//

import Foundation
import CoreImage
import UIKit

let MaxDepth: Float32 = 25.0

class DepthEncoder {
    enum Status {
        case allGood
        case frameEncodingError
    }
    private var currentFrame: UInt = 0
    private let baseDirectory: URL
    public var status: Status = Status.allGood

    init(outDirectory: URL) {
        self.baseDirectory = outDirectory
        do {
            try FileManager.default.createDirectory(at: outDirectory.absoluteURL, withIntermediateDirectories: true, attributes: nil)
        } catch let error {
            print("Could not create folder. \(error.localizedDescription)")
            status = Status.frameEncodingError
        }
    }

    func encodeFrame(frame: CVPixelBuffer) {
        let ciImage = CIImage(cvPixelBuffer: convert(frame: frame))
        let image = UIImage(ciImage: ciImage, scale: 1.0, orientation: UIImage.Orientation.right)
        let data = image.pngData()
        let filename = String(format: "%05d", currentFrame)
        let framePath = baseDirectory.absoluteURL.appendingPathComponent(filename, isDirectory: false).appendingPathExtension("png")
        do {
            try data?.write(to: framePath)
        } catch let error {
            print("Could not save depth image. \(error.localizedDescription)")
        }
        currentFrame += 1
    }

    private func convert(frame: CVPixelBuffer) -> CVPixelBuffer {
        // Converts a CVPixelBuffer from depth32 to UInt16
        var newFrame: CVPixelBuffer? = nil
        let options = [ kCVPixelBufferCGImageCompatibilityKey as String: true, kCVPixelBufferCGBitmapContextCompatibilityKey as String: true ]
        let height = CVPixelBufferGetHeight(frame)
        let width = CVPixelBufferGetWidth(frame)
        CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_DepthFloat32, options as CFDictionary, &newFrame)
        let outBuffer = newFrame!
        CVPixelBufferLockBaseAddress(frame, CVPixelBufferLockFlags.readOnly)
        CVPixelBufferLockBaseAddress(outBuffer, CVPixelBufferLockFlags(rawValue: 1))
        let outBase = CVPixelBufferGetBaseAddress(outBuffer)
        let inBase = CVPixelBufferGetBaseAddress(frame)
        let outPixelData = outBase!.assumingMemoryBound(to: Float32.self)
        let inPixelData = inBase!.assumingMemoryBound(to: Float32.self)
        DispatchQueue.concurrentPerform(iterations: height) { row in
            for column in 1...width {
                let index = row * width + column
                let pixelValueIn: Float32 = inPixelData[index]
                outPixelData[index] = min(pixelValueIn / MaxDepth, 1.0)
            }
        }
        CVPixelBufferUnlockBaseAddress(outBuffer, CVPixelBufferLockFlags(rawValue: 0))
        CVPixelBufferUnlockBaseAddress(frame, CVPixelBufferLockFlags(rawValue: 0))

        return outBuffer
    }
}
