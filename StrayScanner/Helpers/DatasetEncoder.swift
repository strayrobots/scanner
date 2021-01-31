//
//  DatasetEncoder.swift
//  StrayScanner
//
//  Created by Kenneth Blomqvist on 1/2/21.
//  Copyright © 2021 Stray Robots. All rights reserved.
//

import Foundation
import ARKit
import CryptoKit

let MaxDepth: Float = 25.0
let DepthMultiplier: Float = Float(UInt16.max) / MaxDepth

class DatasetEncoder {
    enum Status {
        case allGood
        case videoEncodingError
        case directoryCreationError
    }
    private let rgbEncoder: VideoEncoder
    private let depthEncoder: DepthEncoder
    private let datasetDirectory: URL
    public let id: UUID
    public let rgbFilePath: URL // Relative to app document directory.
    public let depthFilePath: URL // Relative to app document directory.
    public var status = Status.allGood

    init(arConfiguration: ARWorldTrackingConfiguration) {
        let width = arConfiguration.videoFormat.imageResolution.width
        let height = arConfiguration.videoFormat.imageResolution.height
        var theId: UUID = UUID()
        datasetDirectory = DatasetEncoder.createDirectory(id: &theId)
        self.id = theId
        self.rgbFilePath = datasetDirectory.appendingPathComponent("rgb.mp4")
        self.rgbEncoder = VideoEncoder(file: self.rgbFilePath, width: width, height: height)
        self.depthFilePath = datasetDirectory.appendingPathComponent("depth", isDirectory: true)
        self.depthEncoder = DepthEncoder(outDirectory: self.depthFilePath)
    }

    func addFrame(frame: ARFrame) {
        self.rgbEncoder.addFrame(frame: VideoEncoderInput(buffer: frame.capturedImage, time: frame.timestamp))
        if let sceneDepth = frame.sceneDepth {
            //let newBuffer = convert(buffer: sceneDepth.depthMap)
            self.depthEncoder.encodeFrame(frame: sceneDepth.depthMap)
        }
    }

    private func convert(buffer: CVPixelBuffer) -> CVPixelBuffer {
        let width = CVPixelBufferGetWidth(buffer)
        let height = CVPixelBufferGetHeight(buffer)
        let currentType = CVPixelBufferGetPixelFormatType(buffer)
        assert(currentType == kCVPixelFormatType_DepthFloat32, "Pixels of wrong format")
        var out: CVPixelBuffer?

        let options = [ kCVPixelBufferCGImageCompatibilityKey as String: true, kCVPixelBufferCGBitmapContextCompatibilityKey as String: true ]
        let success = CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_16Gray, options as CFDictionary, &out)
        assert(success == kCVReturnSuccess, "Could not create CVPixelBuffer")
        print("Width: \(width) height: \(height) success: \(success)")
        print("Width: \(CVPixelBufferGetWidth(out!)) height: \(CVPixelBufferGetHeight(out!)) success: \(success)")
        let outBuffer = out!
        CVPixelBufferLockBaseAddress(buffer, CVPixelBufferLockFlags.readOnly)
        CVPixelBufferLockBaseAddress(outBuffer, CVPixelBufferLockFlags(rawValue: 1))

        let outBase = CVPixelBufferGetBaseAddress(outBuffer)
        let inBase = CVPixelBufferGetBaseAddress(buffer)
        let outPixelData = outBase!.assumingMemoryBound(to: UInt16.self)
        let inPixelData = inBase!.assumingMemoryBound(to: Float32.self)

        DispatchQueue.concurrentPerform(iterations: height) { row in
            for column in 0 ..< width {
                let indexIn = row * width + column
                let pixelValueIn: Float32 = inPixelData[indexIn]
                let pixelValueOut: UInt16 = UInt16(round(pixelValueIn * DepthMultiplier))
                let indexOut = row * width + column
                outPixelData[indexOut] = pixelValueOut
            }
        }
        CVPixelBufferUnlockBaseAddress(outBuffer, CVPixelBufferLockFlags(rawValue: 0))
        CVPixelBufferUnlockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))
        return outBuffer
    }

    func wrapUp() {
        self.rgbEncoder.finishEncoding()
        switch self.rgbEncoder.status {
            case .allGood:
                status = .allGood
            case .error:
                status = .videoEncodingError
        }
        switch self.depthEncoder.status {
            case .allGood:
                status = .allGood
            case .frameEncodingError:
                status = .videoEncodingError
                print("Something went wrong encoding depth.")
        }
    }

    static private func createDirectory(id: inout UUID) -> URL {
        let directoryId = hashUUID(id: id)
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        var directory = URL(fileURLWithPath: directoryId, relativeTo: url)
        if FileManager.default.fileExists(atPath: directory.absoluteString) {
            // Just in case the first 5 characters clash, try again.
            id = UUID()
            directory = DatasetEncoder.createDirectory(id: &id)
        }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
        } catch let error as NSError {
            print("Error creating directory. \(error), \(error.userInfo)")
        }
        return directory
    }

    static private func hashUUID(id: UUID) -> String {
        var hasher: SHA256 = SHA256()
        hasher.update(data: id.uuidString.data(using: .ascii)!)
        let digest = hasher.finalize()
        var string = ""
        digest.makeIterator().prefix(5).forEach { (byte: UInt8) in
            string += String(format: "%02x", byte)
        }
        print("Hash: \(string)")
        return string
    }
}
