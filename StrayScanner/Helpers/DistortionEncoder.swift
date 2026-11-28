//
//  DistortionEncoder.swift
//  StrayScanner
//
//  Created by Kenneth Blomqvist on 4/4/26.
//  Copyright © 2026 Stray Robots. All rights reserved.
//

import Foundation
import ARKit
import AVFoundation

class DistortionEncoder {
    private let distortionDirectory: URL
    private var isInitialized = false

    init(datasetDirectory: URL) {
        self.distortionDirectory = datasetDirectory.appendingPathComponent("distortion", isDirectory: true)
    }

    func add(lookupTable: Data, currentFrame: Int) {
        if !isInitialized {
            isInitialized = true
            do {
                try FileManager.default.createDirectory(at: distortionDirectory, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("Could not create distortion directory: \(error)")
                return
            }
        }

        let frameNumber = String(format: "%06d", currentFrame)
        let filePath = distortionDirectory
            .appendingPathComponent(frameNumber)
            .appendingPathExtension("bin")
        do {
            try lookupTable.write(to: filePath)
        } catch {
            print("Could not write distortion lookup table for frame \(currentFrame): \(error)")
        }
    }

    func done() {}
}
