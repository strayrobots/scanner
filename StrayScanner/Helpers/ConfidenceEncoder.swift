//
//  ConfidenceEncoder.swift
//  StrayScanner
//
//  Created by Kenneth Blomqvist on 3/13/21.
//  Copyright © 2021 Stray Robots. All rights reserved.
//

import Foundation
import CoreImage

class ConfidenceEncoder {
    enum Status {
        case allGood
        case encodingError
    }
    private var currentFrame: UInt = 0
    private let baseDirectory: URL
    private let ciContext: CIContext
    public var status: Status = Status.allGood

    init(outDirectory: URL) {
        self.baseDirectory = outDirectory
        self.ciContext = CIContext()
        do {
            try FileManager.default.createDirectory(at: outDirectory.absoluteURL, withIntermediateDirectories: true, attributes: nil)
        } catch let error {
            print("Could not create confidence folder. \(error.localizedDescription)")
            status = Status.encodingError
        }
    }

    func encodeFrame(frame: CVPixelBuffer) {
        let filename = String(format: "%06d", currentFrame)
        currentFrame += 1
        DispatchQueue.global(qos: .background).async {
            let image = CIImage(cvPixelBuffer: frame)
            assert(CVPixelBufferGetPixelFormatType(frame) == kCVPixelFormatType_OneComponent8)
            let framePath = self.baseDirectory.absoluteURL.appendingPathComponent(filename, isDirectory: false).appendingPathExtension("png")

            if let colorSpace = CGColorSpace(name: CGColorSpace.extendedGray) {
                do {
                    try self.ciContext.writePNGRepresentation(of: image, to: framePath, format: CIFormat.L8, colorSpace: colorSpace)
                } catch let error {
                    print("Could not save confidence value. \(error.localizedDescription)")
                }
            }
        }
    }
}
