//
//  OdometryEncoder.swift
//  StrayScanner
//
//  Created by Kenneth Blomqvist on 1/31/21.
//  Copyright © 2021 Stray Robots. All rights reserved.
//

import Foundation
import Accelerate
import ARKit
import AVFoundation

class OdometryEncoder {
    let path: URL
    let q_AC = simd_quatf(ix: 1.0, iy: 0.0, iz: 0.0, r: 0.0)
    var transforms: [simd_float4x4] = []
    let fileHandle: FileHandle
    
    init(url: URL) {
        self.path = url
        do {
            try "".write(to: self.path, atomically: true, encoding: .utf8)
            self.fileHandle = try FileHandle(forWritingTo: self.path)
            self.fileHandle.write("timestamp, frame, x, y, z, qx, qy, qz, qw, fx, fy, cx, cy, distortion_center_x, distortion_center_y\n".data(using: .utf8)!)
        } catch let error {
            print("Can't create file \(self.path.absoluteString). \(error.localizedDescription)")
            preconditionFailure("Can't open odometry file for writing.")
        }
        
    }

    func add(frame: ARFrame, currentFrame: Int) {
        let transform = frame.camera.transform
        transforms.append(transform)
        let xyz: vector_float3 = getTranslation(T: transform)
        let q_WA = simd_quatf(transform)
        let q: vector_float4 = (q_WA * q_AC).vector
        let frameNumber = String(format: "%06d", currentFrame)

        let intrinsics = frame.camera.intrinsics
        let fx = intrinsics.columns.0.x
        let fy = intrinsics.columns.1.y
        let cx = intrinsics.columns.2.x
        let cy = intrinsics.columns.2.y

        let distortionCenter = frame.capturedDepthData?.cameraCalibrationData?.lensDistortionCenter
        let dcx = distortionCenter.map { "\($0.x)" } ?? ""
        let dcy = distortionCenter.map { "\($0.y)" } ?? ""

        let line = "\(frame.timestamp), \(frameNumber), \(xyz.x), \(xyz.y), \(xyz.z), \(q.x), \(q.y), \(q.z), \(q.w), \(fx), \(fy), \(cx), \(cy), \(dcx), \(dcy)\n"
        self.fileHandle.write(line.data(using: .utf8)!)
    }

    /// Used by capture pipelines that have no pose estimate, such as the
    /// AVFoundation dual camera mode. The pose columns are written as `nan` so
    /// downstream parsers still see the same schema.
    func add(timestamp: TimeInterval, currentFrame: Int, intrinsics: matrix_float3x3?) {
        let frameNumber = String(format: "%06d", currentFrame)
        let fx = intrinsics.map { "\($0.columns.0.x)" } ?? "nan"
        let fy = intrinsics.map { "\($0.columns.1.y)" } ?? "nan"
        let cx = intrinsics.map { "\($0.columns.2.x)" } ?? "nan"
        let cy = intrinsics.map { "\($0.columns.2.y)" } ?? "nan"
        let line = "\(timestamp), \(frameNumber), nan, nan, nan, nan, nan, nan, nan, \(fx), \(fy), \(cx), \(cy), , \n"
        self.fileHandle.write(line.data(using: .utf8)!)
    }

    func done() {
        do {
            try self.fileHandle.close()
        } catch let error {
            print("Can't close odometry file \(self.path.absoluteString). \(error.localizedDescription)")
        }
    }

    private func getTranslation(T: simd_float4x4) -> vector_float3 {
        let t = T[3]
        return vector_float3(t.x, t.y, t.z)
    }
}
