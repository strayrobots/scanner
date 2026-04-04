//
//  SettingsConstants.swift
//  StrayScanner
//
//  Constants for settings keys and default values
//

import Foundation

// MARK: - UserDefaults Keys
let FpsUserDefaultsKey: String = "FPS"
let AdaptiveThresholdPositionKey: String = "AdaptiveThresholdPosition"
let AdaptiveThresholdAngleKey: String = "AdaptiveThresholdAngle"

// MARK: - FPS Settings
let FpsDividers: [Int] = [1, 2, 4, 12, 60]
let AvailableFpsSettings: [Int] = FpsDividers.map { Int(60 / $0) }
let AdaptiveModeIndex: Int = -1 // Special index for adaptive mode

// MARK: - Adaptive Mode Defaults
let DefaultAdaptiveThresholdPosition: Double = 0.15 // 15cm
let DefaultAdaptiveThresholdAngle: Double = 15.0 // 15 degrees