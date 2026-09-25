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

struct SessionDetailView: View {
    @ObservedObject var recording: Recording
    @Environment(\.managedObjectContext) private var dataContext
    @Environment(\.dismiss) private var dismiss
    @State private var showingShareSheet = false
    @State private var packageURL: URL?
    @State private var isCreatingPackage = false
    @State private var player: AVPlayer?
    @State private var shareError: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                VideoPlayer(player: player)
                    .aspectRatio(4.0 / 3.0, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .onAppear {
                        if player == nil, let url = recording.absoluteRgbPath() {
                            player = AVPlayer(url: url)
                        }
                    }

                HStack(spacing: 20) {
                    Button(action: shareItem) {
                        HStack {
                            if isCreatingPackage {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "square.and.arrow.up")
                            }
                            Text(isCreatingPackage ? "Preparing..." : "Share")
                                .fixedSize()
                        }
                        .foregroundStyle(isCreatingPackage ? .gray : .blue)
                        .frame(minWidth: 100)
                    }
                    .disabled(isCreatingPackage)

                    Button(action: deleteItem) {
                        Text("Delete").foregroundStyle(Color("DangerColor"))
                    }
                }
                .padding(.top, 20)

                if let directory = recording.directoryPath() {
                    RecordingReportView(directory: directory, duration: recording.duration)
                        .padding(.top, 28)
                }
            }
        }
        .navigationTitle(title)
        .background(Color("BackgroundColor").ignoresSafeArea())
        .sheet(isPresented: $showingShareSheet, onDismiss: removePackage) {
            if let packageURL {
                ShareSheet(activityItems: [packageURL]) {
                    showingShareSheet = false
                }
            }
        }
        .alert("Export Failed", isPresented: Binding(
            get: { shareError != nil },
            set: { if !$0 { shareError = nil } }
        )) {
            Button("OK", role: .cancel) { shareError = nil }
        } message: {
            Text(shareError ?? "")
        }
    }

    private var title: String {
        recording.createdAt?.formatted(date: .long, time: .shortened) ?? recording.name ?? "Recording"
    }

    private func deleteItem() {
        recording.deleteFiles()
        dataContext.delete(recording)
        do {
            try dataContext.save()
        } catch let error as NSError {
            print("Could not save recording. \(error), \(error.userInfo)")
        }
        dismiss()
    }

    private func shareItem() {
        guard let directory = recording.directoryPath() else { return }
        isCreatingPackage = true
        Task {
            do {
                packageURL = try await ShareUtility.createShareableArchive(from: directory)
                showingShareSheet = true
            } catch {
                shareError = error.localizedDescription
            }
            isCreatingPackage = false
        }
    }

    /// Cleans up the temporary package after sharing.
    private func removePackage() {
        if let packageURL {
            try? FileManager.default.removeItem(at: packageURL)
        }
        packageURL = nil
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    let onComplete: @MainActor () -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        controller.completionWithItemsHandler = { _, _, _, _ in
            onComplete()
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
