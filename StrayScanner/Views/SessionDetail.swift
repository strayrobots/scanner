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
    
    func title(recording: Recording) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .short
        
        if let created = recording.createdAt {
            return dateFormatter.string(from: created)
        } else {
            return recording.name ?? "Recording"
        }
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
        let width = UIScreen.main.bounds.size.width
        let height = width * 0.75
        ZStack {
        Color("BackgroundColor")
            .edgesIgnoringSafeArea(.all)
        VStack {
            let player = AVPlayer(url: recording.absoluteRgbPath() ?? defaultUrl)
            VideoPlayer(player: player)
                .frame(width: width, height: height)
                .padding(.horizontal, 0.0)
            Button(action: deleteItem) {
                Text("Delete").foregroundColor(Color("DangerColor"))
            }
        }
        .navigationBarTitle(viewModel.title(recording: recording))
        .background(Color("BackgroundColor"))
        }
    }

    func deleteItem() {
        viewModel.delete(recording: recording)
        self.presentationMode.wrappedValue.dismiss()
    }
}



struct SessionDetailView_Previews: PreviewProvider {
    static var recording: Recording = { () -> Recording in
        let rec = Recording()
        rec.id = UUID()
        rec.name = "Placeholder name"
        rec.createdAt = Date()
        rec.duration = 30.0
        return rec
    }()

    static var previews: some View {
        SessionDetailView(recording: recording)
    }
}
