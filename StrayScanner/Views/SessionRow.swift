//
//  SessionRow.swift
//  Stray Scanner
//
//  Created by Kenneth Blomqvist on 11/15/20.
//  Copyright © 2020 Stray Robots. All rights reserved.
//

import SwiftUI

struct SessionRow: View {
    var session: Recording
    
    var body: some View {
        let duration = String(format: "%ds", Int(round(session.duration)))
        HStack {
            VStack(alignment: .leading) {
                Text(sessionTitle())
                    .multilineTextAlignment(.leading)
                    .padding(.leading, 0.0)
                Text("\(duration)")
                    .font(.caption)
                    .multilineTextAlignment(.leading)
                    .padding(.leading, 0.0)
            }
            Spacer()
        }
    }
    
    private func sessionTitle() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .short
        
        if let created = session.createdAt {
            return dateFormatter.string(from: created)
        } else {
            return "Session"
        }
    }
}

