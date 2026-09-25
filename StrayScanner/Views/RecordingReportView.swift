//
//  RecordingReportView.swift
//  StrayScanner
//
//  Shows what a recording holds on disk: frame counts, depth, confidence, camera, motion and storage.
//

import SwiftUI

struct RecordingReportView: View {
    let directory: URL
    let duration: Double
    @State private var report: DatasetReport?

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("Report")
                .font(.title3)
                .fontWeight(.bold)
            if let report {
                sections(report)
            } else {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Reading the dataset")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .font(.subheadline)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.bottom, 32)
        .task(id: directory) {
            report = await DatasetReport.read(directory: directory)
        }
    }

    @ViewBuilder
    private func sections(_ report: DatasetReport) -> some View {
        section("Frames") {
            row("Video", report.rgbFrames.map(String.init) ?? "Not readable")
            row("Depth maps", "\(report.depthFrames)")
            row("Confidence maps", "\(report.confidenceFrames)")
            row("Poses", "\(report.odometryRows)")
            row("Agreement", report.frameCountSpread <= 2 ? "Counts agree" : "Counts differ by \(report.frameCountSpread)")
            if duration > 0 {
                row("Rate", String(format: "%.1f frames per second", Double(report.depthFrames) / duration))
            }
        }

        if let depth = report.depth, let frame = report.sampledFrame {
            section("Depth, frame \(String(format: "%06d", frame))") {
                row("Resolution", "\(depth.width) × \(depth.height), \(depth.bitsPerComponent) bit")
                row("Nearest", metres(depth.minimumMillimetres))
                row("Median", metres(depth.medianMillimetres))
                row("Farthest", metres(depth.maximumMillimetres))
                row("Valid pixels", percent(depth.validShare))
            }
        }

        if let confidence = report.confidence {
            section("Confidence, same frame") {
                row("High", percent(confidence.high))
                row("Medium", percent(confidence.medium))
                row("Low", percent(confidence.low))
                if confidence.unexpected > 0 {
                    row("Other values", "\(confidence.unexpected) pixels")
                }
            }
        }

        section("Camera") {
            if let width = report.rgbWidth, let height = report.rgbHeight {
                row("Video size", "\(width) × \(height)")
            }
            if let intrinsics = report.intrinsics {
                row("Focal length", String(format: "%.1f, %.1f px", intrinsics.fx, intrinsics.fy))
                row("Principal point", String(format: "%.1f, %.1f px", intrinsics.cx, intrinsics.cy))
            }
            row("Camera matrix", report.hasCameraMatrix ? "Present" : "Missing")
            row("Lens distortion", report.distortionFrames > 0 ? "\(report.distortionFrames) tables" : "None")
        }

        section("Motion") {
            row("IMU samples", "\(report.imuRows)")
            if let rate = report.imuRate {
                row("IMU rate", String(format: "%.0f per second", rate))
            }
        }

        section("Storage") {
            row("Size", report.sizeBytes.formatted(.byteCount(style: .file)))
            row("Folder", report.folderName)
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .fontWeight(.semibold)
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                content()
            }
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label)
                .foregroundStyle(.secondary)
            Text(value)
                .monospacedDigit()
                .textSelection(.enabled)
        }
    }

    private func metres(_ millimetres: Int) -> String {
        String(format: "%.2f m", Double(millimetres) / 1000)
    }

    private func percent(_ share: Double) -> String {
        share.formatted(.percent.precision(.fractionLength(1)))
    }
}
