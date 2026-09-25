//
//  SessionList.swift
//  Stray Scanner
//
//  Created by Kenneth Blomqvist on 11/15/20.
//  Copyright © 2020 Stray Robots. All rights reserved.
//

import SwiftUI
import CoreData

struct SessionList: View {
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Recording.createdAt, ascending: false)])
    private var sessions: FetchedResults<Recording>
    @State private var showingInfo = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading) {
                HStack {
                    Text("Recordings")
                        .foregroundStyle(Color("TextColor"))
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding([.top, .leading], 15.0)
                    Spacer()
                    Button {
                        showingInfo = true
                    } label: {
                        Image(systemName: "info.circle")
                            .resizable()
                            .frame(width: 25, height: 25)
                            .padding(.top, 17)
                            .padding(.trailing, 20)
                            .foregroundStyle(Color("TextColor"))
                    }
                    .accessibilityLabel("About")
                }

                if !sessions.isEmpty {
                    List(sessions) { recording in
                        NavigationLink {
                            SessionDetailView(recording: recording)
                        } label: {
                            SessionRow(session: recording)
                        }
                    }
                    .scrollContentBackground(.hidden)
                    Spacer()
                } else {
                    Spacer()
                    Text("No recorded sessions. Record one, and it will appear here.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 50.0)
                }
                HStack {
                    Spacer()
                    NavigationLink {
                        NewSessionView()
                    } label: {
                        Text("Record new session")
                            .font(.title3)
                            .padding(20)
                            .background(Color("TextColor"))
                            .foregroundStyle(Color("LightColor"))
                            .clipShape(.capsule)
                            .padding(20)
                    }
                    Spacer()
                }
                if sessions.isEmpty {
                    Spacer()
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .background(Color("BackgroundColor").ignoresSafeArea())
            .sheet(isPresented: $showingInfo) {
                InformationView()
            }
            .onAppear {
                (UIApplication.shared.delegate as? AppDelegate)?.appDaemon?.removeDeletedEntries()
            }
        }
    }
}
