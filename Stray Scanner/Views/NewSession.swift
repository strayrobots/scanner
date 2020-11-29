//
//  NewSession.swift
//  Stray Scanner
//
//  Created by Kenneth Blomqvist on 11/28/20.
//  Copyright © 2020 Stray Robots. All rights reserved.
//

import SwiftUI

struct RecordSessionManager: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> some UIViewController {
        return RecordSessionViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {
    }
}

struct NewSessionView : View {

    var body: some View {

        RecordSessionManager()
    }
}

struct NewSessionView_Previews: PreviewProvider {
    static var previews: some View {
        NewSessionView()
    }
}
