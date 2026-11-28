//
//  DepthEncoder.swift
//  StrayScanner
//
//  Created by Kenneth Blomqvist on 1/24/21.
//  Copyright © 2021 Stray Robots. All rights reserved.
//

import Foundation
import CoreVideo

// A single-plane pixel buffer copied out of an ARFrame, with rows packed tightly.
// Copying lets the ARFrame (and ARKit's pooled camera buffers) be released right
// away instead of being held until the PNG has been written.
struct PlaneCopy {
    let data: Data
    let width: Int
    let height: Int

    init(_ buffer: CVPixelBuffer, bytesPerPixel: Int) {
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        let width = CVPixelBufferGetWidth(buffer)
        let height = CVPixelBufferGetHeight(buffer)
        self.width = width
        self.height = height
        let rowBytes = width * bytesPerPixel
        let stride = CVPixelBufferGetBytesPerRow(buffer)
        let base = CVPixelBufferGetBaseAddress(buffer)!
        var data = Data(count: rowBytes * height)
        data.withUnsafeMutableBytes { (out: UnsafeMutableRawBufferPointer) in
            for row in 0..<height {
                memcpy(out.baseAddress! + row * rowBytes, base + row * stride, rowBytes)
            }
        }
        self.data = data
    }
}

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

    // frame is a copy of a kCVPixelFormatType_DepthFloat32 buffer, in meters.
    func encodeFrame(frame: PlaneCopy, frameNumber: Int) {
        let filename = String(format: "%06d", frameNumber)
        let encoder = frame.data.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) in
            PngEncoder(depth: bytes.bindMemory(to: Float32.self).baseAddress!, width: Int32(frame.width), height: Int32(frame.height))!
        }
        guard let data = encoder.fileContents() else {
            print("Could not encode depth image \(frameNumber).")
            status = .frameEncodingError
            return
        }
        let framePath = self.baseDirectory.absoluteURL.appendingPathComponent(filename, isDirectory: false).appendingPathExtension("png")
        do {
            try data.write(to: framePath)
        } catch let error {
            print("Could not save depth image \(frameNumber). \(error.localizedDescription)")
            status = .frameEncodingError
        }
    }
}
