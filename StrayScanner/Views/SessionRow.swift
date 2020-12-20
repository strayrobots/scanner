//
//  SessionRow.swift
//  Stray Scanner
//
//  Created by Kenneth Blomqvist on 11/15/20.
//  Copyright © 2020 Stray Robots. All rights reserved.
//

import SwiftUI

struct SessionRow: View {
    var session: Session
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(session.name)
                    .multilineTextAlignment(.leading)
                    .padding(.leading, 0.0)
                Text("\(session.length) s")
                    .font(.caption)
                    .multilineTextAlignment(.leading)
                    .padding(.leading, 0.0)

            }
            Spacer()
        }

    }
}

struct SessionRow_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            SessionRow(session: sessionData[0])
        }
        .previewLayout(.fixed(width: 300, height: 50))
    }
}
