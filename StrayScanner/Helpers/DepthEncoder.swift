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
        let ciImage = CIImage(cvPixelBuffer: frame)
        let image = UIImage(ciImage: ciImage)
        let data = image.pngData()
        let filename = String(format: "%05d.png", currentFrame)
        currentFrame += 1
        let framePath = baseDirectory.appendingPathComponent(filename)
        do {
            try FileManager.default.createFile(atPath: framePath.absoluteString, contents: data, attributes: nil)
        } catch let error {
            status = Status.frameEncodingError
            print("Could not write frame \(filename). \(error.localizedDescription)")
        }
    }
}
