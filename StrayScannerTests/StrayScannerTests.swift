//
//  StrayScannerTests.swift
//  StrayScannerTests
//
//  Created by Kenneth Blomqvist on 2/27/21.
//  Copyright © 2021 Stray Robots. All rights reserved.
//

import XCTest
import ImageIO
import UniformTypeIdentifiers
@testable import StrayScanner

final class StrayScannerTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        for name in ["depth", "confidence"] {
            try FileManager.default.createDirectory(at: directory.appending(path: name), withIntermediateDirectories: true)
        }
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func testReportReadsCountsDepthConfidenceAndIntrinsics() async throws {
        // Two frames of 4 × 2 pixels. The zero is a pixel without depth.
        let depth: [UInt16] = [0, 1500, 2000, 2500, 3000, 3500, 1800, 2200]
        let confidence: [UInt8] = [0, 1, 2, 2, 2, 1, 0, 2]
        for frame in 0..<2 {
            let name = String(format: "%06d.png", frame)
            try writePNG(depth.flatMap { [UInt8($0 >> 8), UInt8($0 & 0xff)] }, width: 4, height: 2, bits: 16, to: directory.appending(path: "depth/\(name)"))
            try writePNG(confidence, width: 4, height: 2, bits: 8, to: directory.appending(path: "confidence/\(name)"))
        }
        try """
        timestamp, frame, x, y, z, qx, qy, qz, qw, fx, fy, cx, cy, distortion_center_x, distortion_center_y
        10.0, 000000, 0, 0, 0, 0, 0, 0, 1, 1400.5, 1401.5, 960.25, 720.75, ,
        10.1, 000001, 0, 0, 0, 0, 0, 0, 1, 1400.5, 1401.5, 960.25, 720.75, ,

        """.write(to: directory.appending(path: "odometry.csv"), atomically: true, encoding: .utf8)
        try """
        timestamp, a_x, a_y, a_z, alpha_x, alpha_y, alpha_z
        1.0, 0, 0, 0, 0, 0, 0
        1.5, 0, 0, 0, 0, 0, 0
        2.0, 0, 0, 0, 0, 0, 0

        """.write(to: directory.appending(path: "imu.csv"), atomically: true, encoding: .utf8)

        let report = await DatasetReport.read(directory: directory)

        XCTAssertNil(report.rgbFrames)
        XCTAssertEqual(report.depthFrames, 2)
        XCTAssertEqual(report.confidenceFrames, 2)
        XCTAssertEqual(report.odometryRows, 2)
        XCTAssertEqual(report.frameCountSpread, 0)
        XCTAssertEqual(report.imuRows, 3)
        XCTAssertEqual(try XCTUnwrap(report.imuRate), 2.0, accuracy: 0.001)
        XCTAssertEqual(report.intrinsics, .init(fx: 1400.5, fy: 1401.5, cx: 960.25, cy: 720.75))
        XCTAssertEqual(report.sampledFrame, 1)

        let measured = try XCTUnwrap(report.depth)
        XCTAssertEqual(measured.width, 4)
        XCTAssertEqual(measured.height, 2)
        XCTAssertEqual(measured.minimumMillimetres, 1500)
        XCTAssertEqual(measured.medianMillimetres, 2200)
        XCTAssertEqual(measured.maximumMillimetres, 3500)
        XCTAssertEqual(measured.validShare, 7.0 / 8.0, accuracy: 0.0001)

        let shares = try XCTUnwrap(report.confidence)
        XCTAssertEqual(shares.low, 2.0 / 8.0, accuracy: 0.0001)
        XCTAssertEqual(shares.medium, 2.0 / 8.0, accuracy: 0.0001)
        XCTAssertEqual(shares.high, 4.0 / 8.0, accuracy: 0.0001)
        XCTAssertEqual(shares.unexpected, 0)
    }

    func testFrameCountSpreadNamesTheLargestGap() {
        let report = DatasetReport(folderName: "x", rgbFrames: 600, rgbWidth: nil, rgbHeight: nil, depthFrames: 597, confidenceFrames: 597, odometryRows: 598, imuRows: 0, imuRate: nil, distortionFrames: 0, hasCameraMatrix: true, intrinsics: nil, sampledFrame: nil, depth: nil, confidence: nil, sizeBytes: 0)
        XCTAssertEqual(report.frameCountSpread, 3)
    }

    /// Writes a grey PNG from big-endian samples.
    private func writePNG(_ bytes: [UInt8], width: Int, height: Int, bits: Int, to url: URL) throws {
        let bytesPerRow = width * bits / 8
        let bitmapInfo = bits == 16 ? CGBitmapInfo(rawValue: CGImageByteOrderInfo.order16Big.rawValue) : []
        let provider = try XCTUnwrap(CGDataProvider(data: Data(bytes) as CFData))
        let image = try XCTUnwrap(CGImage(width: width, height: height, bitsPerComponent: bits, bitsPerPixel: bits, bytesPerRow: bytesPerRow, space: CGColorSpaceCreateDeviceGray(), bitmapInfo: bitmapInfo, provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent))
        let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
    }
}
