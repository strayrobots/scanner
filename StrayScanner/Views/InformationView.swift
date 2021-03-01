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
This app lets you record video and depth datasets using the camera and LIDAR scanner.
""")

                heading("Transfering Datasets To Your Desktop")
                
                bodyText("""
The recorded datasets can be transfered to your desktop computer by connecting your device to it with the lightning cable.

On Mac, you can access the files through Finder. In the sidebar, select your device. Under the "Files" tab, you should see an entry for StrayScanner. Expand it, then drag the folders to the desired location. There is one folder per dataset, each named after a random alphanumerical hash.

On Windows, you should be able to access the files through iTunes.
""")
                
                heading("Using The Data")
                
                bodyText("Below is a link to a Python script that uses Open3D to visualize the collected data. It contains a detailed description of the semantics for each attribute.")
                
                link(text: "Usage example", destination: "https://keke.dev")
                
                heading("Disclaimer")
                
                bodyText("""
This application is provided as is.

In no event shall the authors or copyright holders be liable for any claim, damages or other liability arising from using, or in connection with using the software.
""")
                Spacer()
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
