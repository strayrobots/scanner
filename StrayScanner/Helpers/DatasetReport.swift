//
//  DatasetReport.swift
//  StrayScanner
//
//  Reads a recorded dataset back from its folder and summarises what it holds.
//

import Foundation
import AVFoundation
import ImageIO

struct DatasetReport: Sendable, Equatable {
    struct Depth: Sendable, Equatable {
        var width: Int
        var height: Int
        var bitsPerComponent: Int
        var minimumMillimetres: Int
        var medianMillimetres: Int
        var maximumMillimetres: Int
        /// Share of pixels with a depth above zero.
        var validShare: Double
    }

    struct Confidence: Sendable, Equatable {
        var low: Double
        var medium: Double
        var high: Double
        /// Pixels outside {0, 1, 2}. Always zero in a sound dataset.
        var unexpected: Int
    }

    struct Intrinsics: Sendable, Equatable {
        var fx: Double
        var fy: Double
        var cx: Double
        var cy: Double
    }

    var folderName: String
    var rgbFrames: Int?
    var rgbWidth: Int?
    var rgbHeight: Int?
    var depthFrames: Int
    var confidenceFrames: Int
    var odometryRows: Int
    var imuRows: Int
    /// IMU samples per second, from the first and last timestamps.
    var imuRate: Double?
    var distortionFrames: Int
    var hasCameraMatrix: Bool
    /// Intrinsics of the first frame, from odometry.csv.
    var intrinsics: Intrinsics?
    /// The frame whose depth and confidence were measured: the middle one.
    var sampledFrame: Int?
    var depth: Depth?
    var confidence: Confidence?
    var sizeBytes: Int64

    /// Largest difference between the frame counts of the video, depth maps, confidence maps and poses.
    var frameCountSpread: Int {
        let counts = [rgbFrames, depthFrames, confidenceFrames, odometryRows].compactMap { $0 }
        return (counts.max() ?? 0) - (counts.min() ?? 0)
    }
}

extension DatasetReport {
    static func read(directory: URL) async -> DatasetReport {
        let depthFiles = files(in: directory.appending(path: "depth"), withExtension: "png")
        let confidenceFiles = files(in: directory.appending(path: "confidence"), withExtension: "png")
        let odometry = CSVSummary(url: directory.appending(path: "odometry.csv"))
        let imu = CSVSummary(url: directory.appending(path: "imu.csv"))
        let sampled = depthFiles.isEmpty ? nil : depthFiles.count / 2
        let video = await readVideo(url: directory.appending(path: "rgb.mp4"))

        var imuRate: Double?
        if imu.rows > 1, let first = imu.first?.first.flatMap(Double.init), let last = imu.last?.first.flatMap(Double.init), last > first {
            imuRate = Double(imu.rows - 1) / (last - first)
        }

        var intrinsics: Intrinsics?
        if let row = odometry.first, row.count >= 13 {
            let values = row[9...12].compactMap(Double.init)
            if values.count == 4 {
                intrinsics = Intrinsics(fx: values[0], fy: values[1], cx: values[2], cy: values[3])
            }
        }

        return DatasetReport(
            folderName: directory.lastPathComponent,
            rgbFrames: video?.frames,
            rgbWidth: video?.width,
            rgbHeight: video?.height,
            depthFrames: depthFiles.count,
            confidenceFrames: confidenceFiles.count,
            odometryRows: odometry.rows,
            imuRows: imu.rows,
            imuRate: imuRate,
            distortionFrames: files(in: directory.appending(path: "distortion"), withExtension: "bin").count,
            hasCameraMatrix: FileManager.default.fileExists(atPath: directory.appending(path: "camera_matrix.csv").path),
            intrinsics: intrinsics,
            sampledFrame: sampled,
            depth: sampled.flatMap { readDepth(url: depthFiles[$0]) },
            confidence: sampled.flatMap { confidenceFiles.indices.contains($0) ? readConfidence(url: confidenceFiles[$0]) : nil },
            sizeBytes: size(of: directory)
        )
    }

    private static func files(in directory: URL, withExtension pathExtension: String) -> [URL] {
        let contents = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        return contents
            .filter { $0.pathExtension == pathExtension }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    private static func size(of directory: URL) -> Int64 {
        guard let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
        var total: Int64 = 0
        for case let url as URL in enumerator {
            total += Int64((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
        return total
    }

    private static func readVideo(url: URL) async -> (frames: Int, width: Int, height: Int)? {
        let asset = AVURLAsset(url: url)
        guard let track = try? await asset.loadTracks(withMediaType: .video).first,
              let naturalSize = try? await track.load(.naturalSize),
              let reader = try? AVAssetReader(asset: asset) else { return nil }
        // Counting compressed samples, without decoding them.
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: nil)
        output.alwaysCopiesSampleData = false
        guard reader.canAdd(output) else { return nil }
        reader.add(output)
        guard reader.startReading() else { return nil }
        var frames = 0
        while let sample = output.copyNextSampleBuffer() {
            frames += CMSampleBufferGetNumSamples(sample)
        }
        guard reader.status == .completed else { return nil }
        return (frames, Int(naturalSize.width), Int(naturalSize.height))
    }

    /// Reads a grey PNG into one value per pixel, honouring the byte order ImageIO reports.
    private static func readGreyPixels(url: URL, bitsPerComponent: Int) -> (width: Int, height: Int, values: [UInt16])? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
              image.bitsPerComponent == bitsPerComponent,
              image.bitsPerPixel == bitsPerComponent,
              let data = image.dataProvider?.data as Data? else { return nil }
        let width = image.width
        let height = image.height
        let bytesPerRow = image.bytesPerRow
        let littleEndian = image.byteOrderInfo == .order16Little
        guard data.count >= bytesPerRow * height else { return nil }
        var values: [UInt16] = []
        values.reserveCapacity(width * height)
        data.withUnsafeBytes { bytes in
            for y in 0..<height {
                let row = y * bytesPerRow
                for x in 0..<width {
                    if bitsPerComponent == 8 {
                        values.append(UInt16(bytes[row + x]))
                    } else {
                        let a = UInt16(bytes[row + 2 * x])
                        let b = UInt16(bytes[row + 2 * x + 1])
                        values.append(littleEndian ? a | b << 8 : a << 8 | b)
                    }
                }
            }
        }
        return (width, height, values)
    }

    static func readDepth(url: URL) -> Depth? {
        guard let image = readGreyPixels(url: url, bitsPerComponent: 16) else { return nil }
        let valid = image.values.filter { $0 > 0 }.sorted()
        guard let minimum = valid.first, let maximum = valid.last else { return nil }
        return Depth(
            width: image.width,
            height: image.height,
            bitsPerComponent: 16,
            minimumMillimetres: Int(minimum),
            medianMillimetres: Int(valid[valid.count / 2]),
            maximumMillimetres: Int(maximum),
            validShare: Double(valid.count) / Double(image.values.count)
        )
    }

    static func readConfidence(url: URL) -> Confidence? {
        guard let image = readGreyPixels(url: url, bitsPerComponent: 8), !image.values.isEmpty else { return nil }
        var counts = [0, 0, 0]
        var unexpected = 0
        for value in image.values {
            if value < 3 { counts[Int(value)] += 1 } else { unexpected += 1 }
        }
        let total = Double(image.values.count)
        return Confidence(low: Double(counts[0]) / total, medium: Double(counts[1]) / total, high: Double(counts[2]) / total, unexpected: unexpected)
    }
}

/// Row count, first and last row of a CSV file whose first line is a header.
private struct CSVSummary {
    var rows = 0
    var first: [String]?
    var last: [String]?

    init(url: URL) {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return }
        let lines = text.split(whereSeparator: \.isNewline).dropFirst()
        rows = lines.count
        first = lines.first.map(Self.fields)
        last = lines.last.map(Self.fields)
    }

    private static func fields(_ line: Substring) -> [String] {
        line.split(separator: ",", omittingEmptySubsequences: false).map { $0.trimmingCharacters(in: .whitespaces) }
    }
}
