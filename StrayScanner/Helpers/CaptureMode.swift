//
//  CaptureMode.swift
//  StrayScanner
//
//  Copyright © 2026 Stray Robots. All rights reserved.
//

import Foundation
import ARKit
import AVFoundation

/// The capture pipelines the recorder can run.
///
/// `lidar` is only reachable on devices with a LiDAR scanner. On devices without
/// one, ARKit cannot produce a depth map at all, so the user picks between an
/// ARKit run without depth (keeps 6-DoF odometry) and an AVFoundation run using
/// the dual camera disparity map (low resolution depth, no odometry).
enum CaptureMode: Int, CaseIterable {
    case lidar
    case noDepth
    case lowResDepth

    var label: String {
        switch self {
        case .lidar: return "lidar depth"
        case .noDepth: return "no depth"
        case .lowResDepth: return "low-res depth"
        }
    }

    /// Whether the pipeline writes a depth stream.
    var recordsDepth: Bool {
        return self != .noDepth
    }

    /// Whether the pipeline produces ARKit camera poses.
    var recordsOdometry: Bool {
        return self != .lowResDepth
    }

    static var lidarAvailable: Bool {
        return ARWorldTrackingConfiguration.isSupported &&
            ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth)
    }

    static var arkitAvailable: Bool {
        return ARWorldTrackingConfiguration.isSupported
    }

    static var lowResDepthAvailable: Bool {
        return DualCameraCapture.findDevice() != nil
    }

    /// Modes the current device can actually run, in the order the mode button
    /// cycles through them.
    static var available: [CaptureMode] {
        if lidarAvailable {
            // Nothing to choose from: LiDAR depth is strictly better.
            return [.lidar]
        }
        var modes: [CaptureMode] = []
        if arkitAvailable {
            modes.append(.noDepth)
        }
        if lowResDepthAvailable {
            modes.append(.lowResDepth)
        }
        return modes
    }
}
