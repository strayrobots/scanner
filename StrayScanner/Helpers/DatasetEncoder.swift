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

let DepthRange: Float = 1000.0
let UIntMax: Float32 = Float32(UInt32.max)

class DatasetEncoder {
    enum Status {
        case allGood
        case videoEncodingError
        case directoryCreationError
    }
    private let rgbEncoder: VideoEncoder
    private let depthEncoder: VideoEncoder
    private let datasetDirectory: URL
    public let id: UUID
    public let rgbFilePath: URL // Relative to app document directory.
    public let depthFilePath: URL
    public var status = Status.allGood

    init(arConfiguration: ARWorldTrackingConfiguration) {
        let width = arConfiguration.videoFormat.imageResolution.width
        let height = arConfiguration.videoFormat.imageResolution.height
        var theId: UUID = UUID()
        datasetDirectory = DatasetEncoder.createDirectory(id: &theId)
        self.id = theId
        self.rgbFilePath = datasetDirectory.appendingPathComponent("rgb.mp4")
        self.rgbEncoder = VideoEncoder(file: self.rgbFilePath, width: width, height: height, depth: false)
        self.depthFilePath = datasetDirectory.appendingPathComponent("depth.mp4")
        self.depthEncoder = VideoEncoder(file: self.depthFilePath, width: 256, height: 192, depth: true)
    }

    func addFrame(frame: ARFrame) {
        self.rgbEncoder.addFrame(frame: VideoEncoderInput(buffer: frame.capturedImage, time: frame.timestamp))
        if let sceneDepth = frame.sceneDepth {
            let newBuffer = convert(buffer: sceneDepth.depthMap)
            self.depthEncoder.addFrame(frame: VideoEncoderInput(buffer: newBuffer, time: frame.timestamp))
        }
    }

    private func convert(buffer: CVPixelBuffer) -> CVPixelBuffer {
        let width = CVPixelBufferGetWidth(buffer)
        let height = CVPixelBufferGetHeight(buffer)
        let currentType = CVPixelBufferGetPixelFormatType(buffer)
        assert(currentType == kCVPixelFormatType_DepthFloat32, "Pixels of wrong format")
        var out: CVPixelBuffer?

        let options = [ kCVPixelBufferCGImageCompatibilityKey as String: true, kCVPixelBufferCGBitmapContextCompatibilityKey as String: true ]
        let success = CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32ARGB, options as CFDictionary, &out)
        assert(success == kCVReturnSuccess, "Could not create CVPixelBuffer")
        print("Width: \(width) height: \(height) success: \(success)")
        print("Width: \(CVPixelBufferGetWidth(out!)) height: \(CVPixelBufferGetHeight(out!)) success: \(success)")
        let outBuffer = out!
        CVPixelBufferLockBaseAddress(buffer, CVPixelBufferLockFlags.readOnly)
        CVPixelBufferLockBaseAddress(outBuffer, CVPixelBufferLockFlags(rawValue: 1))

        let outBase = CVPixelBufferGetBaseAddress(outBuffer)
        let inBase = CVPixelBufferGetBaseAddress(buffer)
        let outPixelData = outBase!.assumingMemoryBound(to: UInt8.self)
        let inPixelData = inBase!.assumingMemoryBound(to: Float32.self)

        DispatchQueue.concurrentPerform(iterations: height) { row in
            for column in 0 ..< width {
                let indexIn = row * width + column
                let pixelValueIn: Float32 = inPixelData[indexIn]
                let integerValue = UInt32(min(pixelValueIn * DepthRange, UIntMax))
                let byteArray: [UInt8] = withUnsafeBytes(of: integerValue) {
                    Array($0)
                }
                for i in 0 ..< 4 {
                    let indexOut = row * width * 4 + column * 4 + i
                    outPixelData[indexOut] = byteArray[i]

                }
            }
        }
        CVPixelBufferUnlockBaseAddress(outBuffer, CVPixelBufferLockFlags(rawValue: 0))
        CVPixelBufferUnlockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))
        return outBuffer
    }

    func wrapUp() {
        self.rgbEncoder.finishEncoding()
        self.depthEncoder.finishEncoding()
        switch self.rgbEncoder.status {
            case .allGood:
                status = .allGood
            case .error:
                status = .videoEncodingError
        }
        switch self.depthEncoder.status {
            case .allGood:
                status = .allGood
            case .error:
                status = .videoEncodingError
                print("Something went wrong encoding depth.")
        }
        //DispatchQueue.main.async {
        //    var url = FileManager.default.urls(for: .sharedPublicDirectory, in: .allDomainsMask).first!
        //    url = url.appendingPathComponent(self.datasetDirectory.relativeString)
        //    do {
        //        let publicUrl = FileManager.default.urls(for: .sharedPublicDirectory, in: .allDomainsMask).first!
        //        if !FileManager.default.fileExists(atPath: publicUrl.absoluteString) {
        //            try FileManager.default.createDirectory(at: publicUrl, withIntermediateDirectories: true, attributes: nil)
        //        }
        //        try FileManager.default.moveItem(atPath: self.datasetDirectory.absoluteString, toPath: url.absoluteString)
        //    } catch let error {
        //        print("Error moving directory. \(error), \(error.localizedDescription)")
        //    }
        //}
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
