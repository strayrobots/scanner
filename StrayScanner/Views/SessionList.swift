//
//  SessionList.swift
//  Stray Scanner
//
//  Created by Kenneth Blomqvist on 11/15/20.
//  Copyright © 2020 Stray Robots. All rights reserved.
//

import SwiftUI
import CoreData

class SessionListViewModel: ObservableObject {
    private var dataContext: NSManagedObjectContext?
    @Published var sessions: [Recording] = []

    init() {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
        dataContext = appDelegate.persistentContainer.viewContext
        self.sessions = []
        NotificationCenter.default.addObserver(self, selector: #selector(sessionsChanged), name: NSNotification.Name("sessionsChanged"), object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func fetchSessions() {
        let request = NSFetchRequest<NSManagedObject>(entityName: "Recording")
        do {
            let fetched: [NSManagedObject] = try dataContext?.fetch(request) ?? []
            sessions = fetched.map { session in
                return session as! Recording
            }

        } catch let error as NSError {
            print("Something went wrong. Error: \(error), \(error.userInfo)")
        }
    }

    @objc func sessionsChanged() {
        fetchSessions()
    }

}

struct SessionList: View {
    @ObservedObject var viewModel = SessionListViewModel()

    init() {
        UITableView.appearance().backgroundColor = UIColor(named: "BackgroundColor")
    }

    var body: some View {
        ZStack {
        Color.black
        .ignoresSafeArea()
        NavigationView {
            VStack(alignment: .leading) {
                Text("Recordings")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .padding([.top, .leading], 15.0)

                if !viewModel.sessions.isEmpty {
                    List {
                        ForEach(Array(viewModel.sessions.enumerated()), id: \.element) { i, recording in
                            NavigationLink(destination: SessionDetailView(recording: recording)) {
                                SessionRow(session: recording)
                            }
                        }
                    }
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
                if (viewModel.sessions.isEmpty) {
                    Spacer()
                }
            }
            .navigationBarHidden(true)
            .background(Color("BackgroundColor").ignoresSafeArea())
            .onAppear {
                DispatchQueue.main.async {
                    viewModel.fetchSessions()
                }
                FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).forEach({ url in
                    let relative = url.relativeString
                    print("relative url: \(relative)")
                })
                let delegate = UIApplication.shared.delegate as! AppDelegate
                delegate.appDaemon?.removeDeletedEntries()
        }
        }
        .background(Color("BackgroundColor").edgesIgnoringSafeArea(.all))
        }
    }
}

struct SessionList_Previews: PreviewProvider {
    static var previews: some View {
        SessionList()
    }
}
