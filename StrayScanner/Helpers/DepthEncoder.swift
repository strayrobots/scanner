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

    func encodeFrame(frame: CVPixelBuffer, frameNumber: Int) {
        let filename = String(format: "%06d", frameNumber)
        let npyArray = self.convert(frame: frame)
        let data = npyArray.npyFileContents()
        let framePath = self.baseDirectory.absoluteURL.appendingPathComponent(filename, isDirectory: false).appendingPathExtension("npy")
        do {
            try data?.write(to: framePath)
        } catch let error {
            print("Could not save depth image \(frameNumber). \(error.localizedDescription)")
        }
    }

    private func convert(frame: CVPixelBuffer) -> NPYArrayWrapper {
        // Converts a CVPixelBuffer from the depth camera to a numpy array.
        assert(CVPixelBufferGetPixelFormatType(frame) == kCVPixelFormatType_DepthFloat32)
        let height = CVPixelBufferGetHeight(frame)
        let width = CVPixelBufferGetWidth(frame)
        CVPixelBufferLockBaseAddress(frame, CVPixelBufferLockFlags.readOnly)
        let inBase = CVPixelBufferGetBaseAddress(frame)
        let inPixelData = inBase!.assumingMemoryBound(to: Float32.self)
        
        let outArray = NPYArrayWrapper.init(depth: inPixelData, width: Int32(width), height: Int32(height))!
        
        CVPixelBufferUnlockBaseAddress(frame, CVPixelBufferLockFlags(rawValue: 0))

        return outArray;
    }
}
