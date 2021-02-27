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
    enum Status {
        case allGood
        case error
    }
    var currentFrame: Int = 0
    var status: Status = Status.allGood
    let path: URL
    let q_AC = simd_quatf(ix: 1.0, iy: 0.0, iz: 0.0, r: 0.0)
    var transforms: [simd_float4x4] = []

    init(url: URL) {
        self.path = url
    }

    func add(frame: ARFrame) {
        let transform = frame.camera.transform
        transforms.append(transform)
        currentFrame += 1
    }

    func write() {
        var lines: [String] = []
        for transform in transforms {
            let xyz: vector_float3 = getTranslation(T: transform)
            let q_WA = simd_quatf(transform)
            let q: vector_float4 = (q_WA * q_AC).vector
            let line = "\(xyz.x), \(xyz.y), \(xyz.z), \(q.x), \(q.y), \(q.z), \(q.w)"
            lines.append(line)
        }
        let contents = lines.joined(separator: "\n")
        do {
            try contents.write(to: self.path, atomically: true, encoding: String.Encoding.utf8)
        } catch let error {
            print("Could not write csv to file. \(error.localizedDescription)")
            status = Status.error
        }
    }

    private func getTranslation(T: simd_float4x4) -> vector_float3 {
        let t = T[3]
        return vector_float3(t.x, t.y, t.z)
    }
}
