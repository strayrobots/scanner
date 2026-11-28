//
//  ConfidenceEncoder.swift
//  StrayScanner
//
//  Created by Kenneth Blomqvist on 3/13/21.
//  Copyright © 2021 Stray Robots. All rights reserved.
//

import Foundation

class ConfidenceEncoder {
    enum Status {
        case allGood
        case encodingError
    }
    private let baseDirectory: URL
    private var previousFrame: Int = -1
    public var status: Status = Status.allGood

    init(outDirectory: URL) {
        self.baseDirectory = outDirectory
        do {
            try FileManager.default.createDirectory(at: outDirectory.absoluteURL, withIntermediateDirectories: true, attributes: nil)
        } catch let error {
            print("Could not create confidence folder. \(error.localizedDescription)")
            status = Status.encodingError
        }
    }

    // frame is a copy of a kCVPixelFormatType_OneComponent8 buffer with values 0, 1 or 2.
    // Encoded on the CPU with lodepng, like depth, so it doesn't compete with ARKit
    // and the preview for the GPU.
    func encodeFrame(frame: PlaneCopy, frameNumber: Int) {
        if (previousFrame + 1) != frameNumber {
            print("warning: Confidence skipped a frame. \(previousFrame+1) != \(frameNumber)")
        }
        previousFrame = frameNumber
        let filename = String(format: "%06d", frameNumber)
        let framePath = self.baseDirectory.absoluteURL.appendingPathComponent(filename, isDirectory: false).appendingPathExtension("png")
        let encoder = frame.data.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) in
            PngEncoder(gray8: bytes.bindMemory(to: UInt8.self).baseAddress!, width: Int32(frame.width), height: Int32(frame.height))!
        }
        guard let data = encoder.fileContents() else {
            print("Could not encode confidence frame \(frameNumber).")
            status = .encodingError
            return
        }
        do {
            try data.write(to: framePath)
        } catch let error {
            print("Could not save confidence frame \(frameNumber). \(error.localizedDescription)")
            status = .encodingError
        }
    }
}
