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
                Group {
                bodyText("""
This app lets you record video and depth datasets using the camera and LIDAR scanner.
""")

                heading("Transfering Datasets To Your Desktop Computer")
                
                bodyText("""
The recorded datasets can be exported by connecting your device to it with the lightning cable.

On Mac, you can access the files through Finder. In the sidebar, select your device. Under the "Files" tab, you should see an entry for Stray Scanner. Expand it, then drag the folders to the desired location. There is one folder per dataset, each named after a random alphanumerical hash.

On Windows, you can access the files through iTunes.

Alternatively, you can access the data in the Files app under "Browse > On My iPhone > Stray Scanner" and export them to another app or move them to your iCloud drive.
""")
                link(text: "Exporting Data in Docs", destination: "https://docs.strayrobots.io/apps/scanner/export.html")
                }
                Group {
                heading("Post-processing and Annotating Datasets Using Stray Studio")
                bodyText("Stray Studio can compute optimized camera poses, point cloud and mesh reconstructions of your scans. You can also use it to annotate your datasets with semantic labels and export the datasets to train computer vision models.")
                    
                link(text: "Stray Studio", destination: "https://www.strayrobots.io/components/stray-3d-studio")

                heading("Using The Data")
                
                bodyText("Below is a link to an example project which visualizes the data collected by the app. You can use that as a reference and starting point for your own applications. Below, is a detailed description of the collected data.")
                
                link(text: "Usage examples and tools", destination: "https://github.com/kekeblom/StrayVisualizer")
                link(text: "Data model", destination: "https://docs.strayrobots.io/apps/scanner/format.html")
                    
                }
                Group {
                heading("Privacy Policy")

                bodyText("We do not track you. All of the data you record is stored on your device. We don't call home or otherwise collect data about how you use the app.")

                link(text: "Privacy policy", destination: "https://www.notion.so/Privacy-Policy-f1a6b1bcf7ed48098ffe2f50281e5c34")

                heading("Disclaimer")
                bodyText("This application is provided as is.\nIn no event shall the authors or copyright holders be liable for any claim, damages or other liability arising from using, or in connection with using the software.")
                
                Spacer()
                }
            }.padding(.all, paddingLeftRight)
            }
            .frame(minWidth: 0, maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        
        }
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
    
    private func link(text: String, destination: String) -> some View {
        Text(text)
            .font(.body)
            .foregroundColor(Color.blue)
            .padding(.top, paddingTextTop)
            .onTapGesture {
                let url = URL.init(string: destination)
                guard let destinationUrl = url else { return }
                UIApplication.shared.open(destinationUrl)
            }
    }
}

struct InformationView_Previews: PreviewProvider {
    static var previews: some View {
        InformationView()
    }
}
