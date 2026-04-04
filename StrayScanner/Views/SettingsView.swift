//
//  SettingsView.swift
//  StrayScanner
//
//  Settings view for configuring scan parameters
//

import SwiftUI

struct SettingsView: View {
    @AppStorage(FpsUserDefaultsKey) private var fpsSettingIndex: Int = 0
    @AppStorage(AdaptiveThresholdPositionKey) private var adaptiveThresholdPosition: Double = DefaultAdaptiveThresholdPosition
    @AppStorage(AdaptiveThresholdAngleKey) private var adaptiveThresholdAngle: Double = DefaultAdaptiveThresholdAngle
    
    @Environment(\.presentationMode) var presentationMode
    
    init() {
        // Ensure default values are stored in UserDefaults
        if UserDefaults.standard.object(forKey: AdaptiveThresholdPositionKey) == nil {
            UserDefaults.standard.set(DefaultAdaptiveThresholdPosition, forKey: AdaptiveThresholdPositionKey)
        }
        if UserDefaults.standard.object(forKey: AdaptiveThresholdAngleKey) == nil {
            UserDefaults.standard.set(DefaultAdaptiveThresholdAngle, forKey: AdaptiveThresholdAngleKey)
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Adaptive Mode")) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Adaptive mode only captures frames when the camera pose changes significantly. Select 'Adaptive' from the frame rate button during recording to use.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.bottom, 5)
                        
                        VStack(alignment: .leading) {
                            Text("Position Threshold: \(String(format: "%.1f", adaptiveThresholdPosition * 100)) cm")
                                .font(.caption)
                            Slider(value: $adaptiveThresholdPosition, in: 0.01...0.5, step: 0.01)
                        }
                        
                        VStack(alignment: .leading) {
                            Text("Rotation Threshold: \(String(format: "%.1f", adaptiveThresholdAngle))°")
                                .font(.caption)
                            Slider(value: $adaptiveThresholdAngle, in: 1.0...90.0, step: 1.0)
                        }
                    }
                    .padding(.top, 5)
                }
                
                Section(header: Text("About")) {
                    if let version = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                        HStack {
                            Text("Version")
                            Spacer()
                            Text(version)
                        }
                    }
                    HStack {
                        Text("IMU Sample Rate")
                        Spacer()
                        Text("~100 Hz")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Max Video Frame Rate")
                        Spacer()
                        Text("60 fps")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
