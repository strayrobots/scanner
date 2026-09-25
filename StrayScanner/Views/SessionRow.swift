//
//  SessionRow.swift
//  Stray Scanner
//
//  Created by Kenneth Blomqvist on 11/15/20.
//  Copyright © 2020 Stray Robots. All rights reserved.
//

import SwiftUI

struct SessionRow: View {
    @ObservedObject var session: Recording

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(session.createdAt?.formatted(date: .long, time: .shortened) ?? "Session")
                Text("\(Int(session.duration.rounded()))s")
                    .font(.caption)
            }
            Spacer()
        }
    }
}
