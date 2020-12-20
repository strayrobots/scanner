//
//  SessionList.swift
//  Stray Scanner
//
//  Created by Kenneth Blomqvist on 11/15/20.
//  Copyright © 2020 Stray Robots. All rights reserved.
//

import SwiftUI

struct SessionList: View {
    var body: some View {
        NavigationView {
            List(sessionData) { session in
                SessionRow(session: session)
            }
            .navigationBarTitle("Recordings", displayMode: .inline)
            .navigationBarItems(trailing: NavigationLink(destination: NewSessionView(), label: {
                Image(systemName: "plus")
            }))
        }
    }
}

struct SessionList_Previews: PreviewProvider {
    static var previews: some View {
        SessionList()
    }
}
