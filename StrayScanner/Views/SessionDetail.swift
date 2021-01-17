//
//  SessionDetailView.swift
//  StrayScanner
//
//  Created by Kenneth Blomqvist on 12/30/20.
//  Copyright © 2020 Stray Robots. All rights reserved.
//

import SwiftUI
import AVKit
import CoreData

class SessionDetailViewModel: ObservableObject {
    private var dataContext: NSManagedObjectContext?

    init() {
        let appDelegate = UIApplication.shared.delegate as? AppDelegate
        self.dataContext = appDelegate?.persistentContainer.viewContext
    }

    func delete(recording: Recording) {
        recording.deleteFiles()
        self.dataContext?.delete(recording)
        do {
            try self.dataContext?.save()
        } catch let error as NSError {
            print("Could not save recording. \(error), \(error.userInfo)")
        }
    }
}

struct SessionDetailView: View {
    @ObservedObject var viewModel = SessionDetailViewModel()
    var recording: Recording
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>

    let defaultUrl = URL(fileURLWithPath: "")

    var body: some View {
        ZStack {
        Color("BackgroundColor")
            .edgesIgnoringSafeArea(.all)
        VStack {
            let player = AVPlayer(url: recording.absoluteRgbPath() ?? defaultUrl)
            let depthPlayer = AVPlayer(url: recording.absoluteDepthPath() ?? defaultUrl)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 0) {
                    VideoPlayer(player: player)
                        .frame(width: 390, height: 520)
                        .padding(.horizontal, 0.0)
                    VideoPlayer(player: depthPlayer)
                        .frame(width: 390, height: 520)
                        .padding(.horizontal, 0.0)
                }
            }
            .padding(.horizontal)
            .frame(width: 390.0, height: 520.0)
            Button(action: deleteItem) {
                Text("Delete").foregroundColor(Color("DangerColor"))
            }
        }
        .navigationBarTitle(recording.name ?? "Untitled")
        .background(Color("BackgroundColor"))
        }
    }

    func deleteItem() {
        viewModel.delete(recording: recording)
        self.presentationMode.wrappedValue.dismiss()
    }
}

func createRecording() -> Recording {
    let rec = Recording()
    rec.id = UUID()
    rec.name = "Placeholder name"
    rec.createdAt = Date()
    rec.duration = 30.0
    return rec
}

struct SessionDetailView_Previews: PreviewProvider {
    static var recording = createRecording()

    static var previews: some View {
        SessionDetailView(recording: recording)
    }
}
