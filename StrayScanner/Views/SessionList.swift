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

}

struct SessionList: View {
    @ObservedObject var viewModel = SessionListViewModel()

    init() {
        UITableView.appearance().backgroundColor = UIColor(named: "BackgroundColor")
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color("BackgroundColor")
                    .edgesIgnoringSafeArea(.all)
                    .navigationBarTitle("Recordings")
                    .edgesIgnoringSafeArea(.all)
                VStack(alignment: .leading) {
                    if viewModel.sessions.isEmpty {
                        Text("No recorded sessions. Record one, and it will appear here.")
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 50.0)

                    } else {
                        List(viewModel.sessions) { session in
                            SessionRow(session: session)
                        }
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
                }
            }
            .onAppear {
                viewModel.fetchSessions()
            }
        }
    }
}

struct SessionList_Previews: PreviewProvider {
    static var previews: some View {
        SessionList()
    }
}
