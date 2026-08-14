//
//  DualCameraCapture.swift
//  StrayScanner
//
//  Copyright © 2026 Stray Robots. All rights reserved.
//

import Foundation
import AVFoundation
import CoreVideo
import simd

struct DualCameraFrame {
    let video: CVPixelBuffer
    /// Depth in meters, `kCVPixelFormatType_DepthFloat32`. Nil when the depth
    /// output dropped the frame.
    let depth: CVPixelBuffer?
    /// Seconds since boot, same time base as `ARFrame.timestamp`.
    let timestamp: TimeInterval
    /// Intrinsics of the video buffer, if the device delivered them.
    let intrinsics: matrix_float3x3?
}

protocol DualCameraCaptureDelegate: AnyObject {
    func dualCameraCapture(_ capture: DualCameraCapture, didOutput frame: DualCameraFrame)
    func dualCameraCapture(_ capture: DualCameraCapture, didFailWith message: String)
}

/// Captures video plus a low resolution disparity based depth map from the back
/// dual camera system. This is the only way to get a depth map on devices
/// without a LiDAR scanner, but it cannot run at the same time as ARKit since
/// both want exclusive use of the camera.
final class DualCameraCapture: NSObject {
    private let session = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let depthOutput = AVCaptureDepthDataOutput()
    private var synchronizer: AVCaptureDataOutputSynchronizer?
    private let sessionQueue = DispatchQueue(label: "dualCameraCaptureSession")
    private let outputQueue = DispatchQueue(label: "dualCameraCaptureOutput")
    private var configured = false

    weak var delegate: DualCameraCaptureDelegate?

    /// Resolution of the delivered video buffers. Valid after `start()`.
    private(set) var videoResolution = CGSize(width: 1920, height: 1440)

    static func findDevice() -> AVCaptureDevice? {
        let deviceTypes: [AVCaptureDevice.DeviceType] = [
            .builtInDualWideCamera,
            .builtInDualCamera,
            .builtInTripleCamera
        ]
        let discovery = AVCaptureDevice.DiscoverySession(deviceTypes: deviceTypes,
                                                         mediaType: .video,
                                                         position: .back)
        return discovery.devices.first { device in
            device.formats.contains { !$0.supportedDepthDataFormats.isEmpty }
        }
    }

    func start() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if !self.configured {
                guard self.configure() else { return }
                self.configured = true
            }
            if !self.session.isRunning {
                self.session.startRunning()
            }
        }
    }

    func stop(completion: (() -> Void)? = nil) {
        sessionQueue.async { [weak self] in
            if let self = self, self.session.isRunning {
                self.session.stopRunning()
            }
            guard let completion = completion else { return }
            DispatchQueue.main.async(execute: completion)
        }
    }

    private func fail(_ message: String) {
        print(message)
        DispatchQueue.main.async {
            self.delegate?.dualCameraCapture(self, didFailWith: message)
        }
    }

    private func configure() -> Bool {
        guard let device = DualCameraCapture.findDevice() else {
            fail("No depth capable camera available on this device.")
            return false
        }
        guard let (videoFormat, depthFormat) = DualCameraCapture.chooseFormats(device: device) else {
            fail("No camera format with depth support available.")
            return false
        }

        session.beginConfiguration()
        session.sessionPreset = .inputPriority

        do {
            let input = try AVCaptureDeviceInput(device: device)
            guard session.canAddInput(input) else {
                session.commitConfiguration()
                fail("Could not add camera input.")
                return false
            }
            session.addInput(input)
        } catch let error {
            session.commitConfiguration()
            fail("Could not open camera. \(error.localizedDescription)")
            return false
        }

        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
        ]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        guard session.canAddOutput(videoOutput) else {
            session.commitConfiguration()
            fail("Could not add video output.")
            return false
        }
        session.addOutput(videoOutput)

        guard session.canAddOutput(depthOutput) else {
            session.commitConfiguration()
            fail("Could not add depth output.")
            return false
        }
        session.addOutput(depthOutput)
        // Filtering fills in holes, which makes the map far more usable.
        depthOutput.isFilteringEnabled = true
        depthOutput.alwaysDiscardsLateDepthData = true

        do {
            try device.lockForConfiguration()
            device.activeFormat = videoFormat
            device.activeDepthDataFormat = depthFormat
            device.unlockForConfiguration()
        } catch let error {
            session.commitConfiguration()
            fail("Could not configure camera format. \(error.localizedDescription)")
            return false
        }

        // ARKit hands out landscape buffers. Match that so the renderer, the
        // video encoder and the dataset layout stay identical across modes.
        for output in [videoOutput as AVCaptureOutput, depthOutput as AVCaptureOutput] {
            guard let connection = output.connection(with: output === videoOutput ? .video : .depthData) else { continue }
            if #available(iOS 17.0, *) {
                if connection.isVideoRotationAngleSupported(0.0) {
                    connection.videoRotationAngle = 0.0
                }
            } else if connection.isVideoOrientationSupported {
                connection.videoOrientation = .landscapeRight
            }
        }
        if let videoConnection = videoOutput.connection(with: .video),
           videoConnection.isCameraIntrinsicMatrixDeliverySupported {
            videoConnection.isCameraIntrinsicMatrixDeliveryEnabled = true
        }

        session.commitConfiguration()

        let dimensions = CMVideoFormatDescriptionGetDimensions(videoFormat.formatDescription)
        videoResolution = CGSize(width: CGFloat(dimensions.width), height: CGFloat(dimensions.height))

        let synchronizer = AVCaptureDataOutputSynchronizer(dataOutputs: [videoOutput, depthOutput])
        synchronizer.setDelegate(self, queue: outputQueue)
        self.synchronizer = synchronizer
        return true
    }

    /// Picks the highest resolution 4:3 video format that supports depth, plus
    /// the highest resolution float depth format it offers.
    private static func chooseFormats(device: AVCaptureDevice) -> (AVCaptureDevice.Format, AVCaptureDevice.Format)? {
        var best: (video: AVCaptureDevice.Format, depth: AVCaptureDevice.Format, pixels: Int32)?
        for format in device.formats {
            let depthFormats = format.supportedDepthDataFormats.filter { depthFormat in
                let type = CMFormatDescriptionGetMediaSubType(depthFormat.formatDescription)
                return type == kCVPixelFormatType_DepthFloat32 || type == kCVPixelFormatType_DisparityFloat32
            }
            guard !depthFormats.isEmpty else { continue }
            let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            // Keep the 4:3 aspect ratio the preview and dataset assume.
            guard dimensions.width * 3 == dimensions.height * 4 else { continue }
            let pixels = dimensions.width * dimensions.height
            guard best == nil || pixels > best!.pixels else { continue }
            let depthFormat = depthFormats.max { a, b in
                CMVideoFormatDescriptionGetDimensions(a.formatDescription).width <
                    CMVideoFormatDescriptionGetDimensions(b.formatDescription).width
            }!
            best = (format, depthFormat, pixels)
        }
        guard let chosen = best else { return nil }
        return (chosen.video, chosen.depth)
    }
}

extension DualCameraCapture: AVCaptureDataOutputSynchronizerDelegate {
    func dataOutputSynchronizer(_ synchronizer: AVCaptureDataOutputSynchronizer,
                                didOutput synchronizedDataCollection: AVCaptureSynchronizedDataCollection) {
        guard let videoData = synchronizedDataCollection.synchronizedData(for: videoOutput)
                as? AVCaptureSynchronizedSampleBufferData, !videoData.sampleBufferWasDropped,
              let videoBuffer = CMSampleBufferGetImageBuffer(videoData.sampleBuffer) else { return }

        var depthBuffer: CVPixelBuffer?
        if let depthData = synchronizedDataCollection.synchronizedData(for: depthOutput)
            as? AVCaptureSynchronizedDepthData, !depthData.depthDataWasDropped {
            var depth = depthData.depthData
            if depth.depthDataType != kCVPixelFormatType_DepthFloat32 {
                depth = depth.converting(toDepthDataType: kCVPixelFormatType_DepthFloat32)
            }
            depthBuffer = depth.depthDataMap
        }

        let timestamp = CMTimeGetSeconds(videoData.timestamp)
        let intrinsics = DualCameraCapture.intrinsics(from: videoData.sampleBuffer)
        let frame = DualCameraFrame(video: videoBuffer,
                                    depth: depthBuffer,
                                    timestamp: timestamp,
                                    intrinsics: intrinsics)
        delegate?.dualCameraCapture(self, didOutput: frame)
    }

    private static func intrinsics(from sampleBuffer: CMSampleBuffer) -> matrix_float3x3? {
        guard let attachment = CMGetAttachment(sampleBuffer,
                                               key: kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix,
                                               attachmentModeOut: nil) as? Data else { return nil }
        return attachment.withUnsafeBytes { $0.load(as: matrix_float3x3.self) }
    }
}
