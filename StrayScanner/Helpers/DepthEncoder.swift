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
        let filename = String(format: "%06d", currentFrame)
        currentFrame += 1
        DispatchQueue.global(qos: .background).async {
            let ciImage = CIImage(cvPixelBuffer: self.convert(frame: frame))
            let image = UIImage(ciImage: ciImage, scale: 1.0, orientation: UIImage.Orientation.right)
            let data = image.pngData()
            let framePath = self.baseDirectory.absoluteURL.appendingPathComponent(filename, isDirectory: false).appendingPathExtension("png")
            do {
                try data?.write(to: framePath)
            } catch let error {
                print("Could not save depth image. \(error.localizedDescription)")
            }
        }
    }

    private func convert(frame: CVPixelBuffer) -> CVPixelBuffer {
        // Converts a CVPixelBuffer from depth32 to UInt16
        var newFrame: CVPixelBuffer? = nil
        let options = [ kCVPixelBufferCGImageCompatibilityKey as String: true, kCVPixelBufferCGBitmapContextCompatibilityKey as String: true ]
        let height = CVPixelBufferGetHeight(frame)
        let width = CVPixelBufferGetWidth(frame)
        CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_24RGB, options as CFDictionary, &newFrame)
        let outBuffer = newFrame!
        CVPixelBufferLockBaseAddress(frame, CVPixelBufferLockFlags.readOnly)
        CVPixelBufferLockBaseAddress(outBuffer, CVPixelBufferLockFlags(rawValue: 1))
        let inBase = CVPixelBufferGetBaseAddress(frame)
        let inPixelData = inBase!.assumingMemoryBound(to: Float32.self)
        let outBase = CVPixelBufferGetBaseAddress(outBuffer)
        let outPixelData = outBase!.assumingMemoryBound(to: UInt8.self)
        for row in 1...height {
            for column in 1...width {
                let index = row * width + column
                let meters: Float32 = inPixelData[index]
                let floored: Float32 = floor(meters)
                let residualMillimeters: Float32 = (meters - floored) * 1000.0
                let millimeters: UInt = UInt(residualMillimeters)
                let quadrant: UInt = UInt(floor(Float(millimeters / 256)))
                let greenChannel: UInt = millimeters - quadrant * 256
                assert(greenChannel < 256)
                assert(quadrant < 256)
                let outIndex = (row * width + column) * 3
                outPixelData[outIndex] = UInt8(meters)
                outPixelData[outIndex+1] = UInt8(greenChannel)
                outPixelData[outIndex+2] = UInt8(quadrant)
            }
        }
        CVPixelBufferUnlockBaseAddress(outBuffer, CVPixelBufferLockFlags(rawValue: 0))
        CVPixelBufferUnlockBaseAddress(frame, CVPixelBufferLockFlags(rawValue: 0))

        return outBuffer
    }
}
