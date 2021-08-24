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
            self.fileHandle.write("timestamp, frame, x, y, z, qx, qy, qz, qw\n".data(using: .utf8)!)
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
        let line = "\(frame.timestamp), \(frameNumber), \(xyz.x), \(xyz.y), \(xyz.z), \(q.x), \(q.y), \(q.z), \(q.w)\n"
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
