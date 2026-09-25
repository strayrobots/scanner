//
//  InformationView.swift
//  StrayScanner
//
//  Created by Kenneth Blomqvist on 2/28/21.
//  Copyright © 2021 Stray Robots. All rights reserved.
//

import SwiftUI

struct InformationView: View {
    let paddingLeftRight: CGFloat = 15
    let paddingTextTop: CGFloat = 10

    var body: some View {
        ZStack {
            Color("BackgroundColor").ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading) {
                    Text("About This App").font(.title)
                        .fontWeight(.bold)
                    bodyText("""
This app records video and depth datasets with the camera and the LiDAR scanner.
""")
                    bodyText(versionText)
                        .foregroundStyle(.secondary)

                    heading("Transferring Datasets To Your Computer")
                    bodyText("""
The recorded datasets can be exported in several ways:

1. Share from the app: tap Share inside any recording to export it as a ZIP archive through AirDrop, Mail or Files.

2. Connect your device with a cable:
   • On a Mac, open Finder, select your device in the sidebar, open the Files tab, then Stray Scanner.
   • On Windows, use the Apple Devices app.
   • Drag the folders you want to your computer. There is one folder per dataset.

3. Use the Files app: Browse, On My iPhone, Stray Scanner, then move a folder to another app or to iCloud Drive.
""")

                    heading("What A Dataset Holds")
                    bodyText("""
Each dataset folder holds:
   • rgb.mp4, the camera video in HEVC.
   • depth, one 16 bit PNG per frame, 256 × 192, in millimetres.
   • confidence, one 8 bit PNG per frame, with values 0, 1 or 2. Higher is more confident.
   • odometry.csv, the camera pose and intrinsics of each frame.
   • imu.csv, the accelerometer and gyroscope readings.
   • camera_matrix.csv, the 3 × 3 intrinsic matrix of the last frame.
   • distortion, the lens distortion tables, when the device provides them.
""")

                    heading("Report")
                    bodyText("""
Each recording shows a report under its video. It counts the video frames, depth maps, confidence maps and poses, and says whether they agree. It measures the depth and confidence of the middle frame, and lists the camera intrinsics, the motion samples and the size on disk.
""")

                    heading("Source Code")
                    bodyText("This version is built by Izuba from the open source Stray Scanner by Stray Robots, under the MIT licence, and updated for iOS 27.")
                    bodyText("The original project also contains the format documentation and links to related projects. Bugs in the original recorder can be reported there as issues.")
                    link("Stray Scanner on GitHub", destination: "https://github.com/strayrobots/scanner")

                    heading("Disclaimer")
                    bodyText("This application is provided as is.\nIn no event shall the authors or copyright holders be liable for any claim, damages or other liability arising from using, or in connection with using the software.")
                    Spacer()
                }
                .padding(.all, paddingLeftRight)
            }
            .frame(minWidth: 0, maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private var versionText: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "Version \(version) (\(build))"
    }

    private func heading(_ text: String) -> some View {
        Text(text)
            .font(.title3)
            .fontWeight(.bold)
            .padding(.top, 20)
    }

    private func bodyText(_ text: String) -> some View {
        Text(text)
            .font(.body)
            .multilineTextAlignment(.leading)
            .lineSpacing(1.25)
            .padding(.top, paddingTextTop)
    }

    @ViewBuilder
    private func link(_ text: String, destination: String) -> some View {
        if let url = URL(string: destination) {
            Link(text, destination: url)
                .font(.body)
                .padding(.top, paddingTextTop)
        }
    }
}

#Preview {
    InformationView()
}
