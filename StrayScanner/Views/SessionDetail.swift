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

    let defaultUrl = URL(fileURLWithPath: "http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4")

    var body: some View {
        VStack {
            Text(recording.name ?? "Untitled")
            VideoPlayer(player: AVPlayer(url: recording.rgbFilePath ?? defaultUrl))
            Button(action: deleteItem) {
                Text("Delete").foregroundColor(Color("DangerColor"))
            }
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
