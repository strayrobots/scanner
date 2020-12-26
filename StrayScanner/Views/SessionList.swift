//
//  SessionList.swift
//  Stray Scanner
//
//  Created by Kenneth Blomqvist on 11/15/20.
//  Copyright © 2020 Stray Robots. All rights reserved.
//

import SwiftUI

struct SessionList: View {
    init() {
        UITableView.appearance().backgroundColor = UIColor(named: "BackgroundColor")

    }
    var body: some View {
        NavigationView {
            ZStack {
                Color("BackgroundColor")
                    .edgesIgnoringSafeArea(.all)
                VStack(alignment: .leading) {
                    List(sessionData) { session in
                        SessionRow(session: session)
                    }
                    .navigationBarTitle("Recordings")
                    .background(Color.green)
                    .edgesIgnoringSafeArea(.all)
                    HStack {
                        Spacer()
                        NavigationLink(destination: NewSessionView(), label: {
                            Text("Record new session")
                                .font(.title)
                                .padding(25)
                                .background(Color("DarkGrey"))
                                .foregroundColor(Color.white)
                                .cornerRadius(50)
                                .padding(25)
                        })
                        Spacer()
                    }
                }
            }
        }
    }
}

struct SessionList_Previews: PreviewProvider {
    static var previews: some View {
        SessionList()
    }
}
