//
//  NewSession.swift
//  Stray Scanner
//
//  Created by Kenneth Blomqvist on 11/28/20.
//  Copyright © 2020 Stray Robots. All rights reserved.
//

import SwiftUI

struct RecordSessionManager: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> RecordSessionViewController {
        let viewController = RecordSessionViewController(nibName: "RecordSessionView", bundle: nil)
        viewController.setDismissFunction { [weak viewController] in
            dismiss()
            viewController?.setDismissFunction(nil)
        }
        return viewController
    }

    func updateUIViewController(_ uiViewController: RecordSessionViewController, context: Context) {}
}

struct NewSessionView: View {
    var body: some View {
        RecordSessionManager()
            .navigationTitle("Recording")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color("BackgroundColor"), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .ignoresSafeArea()
    }
}
