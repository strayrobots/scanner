//
//  AppDaemon.swift
//  StrayScanner
//
//  Created by Kenneth Blomqvist on 1/17/21.
//  Copyright © 2021 Stray Robots. All rights reserved.
//

import Foundation
import CoreData
import UIKit

class AppDaemon {
    private let dataContext: NSManagedObjectContext?

    init(appDelegate: AppDelegate) {
        dataContext = appDelegate.persistentContainer.viewContext
    }

    public func removeDeletedEntries() {
        let request = NSFetchRequest<NSManagedObject>(entityName: "Recording")
        do {
            let fetched: [NSManagedObject] = try dataContext?.fetch(request) ?? []
            let sessions = fetched.map { session in
                return session as! Recording
            }
            sessions.forEach { session in
                if let path = session.absoluteRgbPath() {
                    let enclosingFolder = path.deletingLastPathComponent()
                    if !FileManager.default.fileExists(atPath: enclosingFolder.path) {
                        // This means that the files have been removed from the device.
                        // For example through finder/iTunes.
                        // This is the main mechanism through which datasets are exported.
                        print("The dataset folder has been removed.")
                        DispatchQueue.main.async {
                            self.removeEntry(session)
                        }
                    }
                } else {
                    print("Session \(session) does not have an rgb file.")
                }
            }

            NotificationCenter.default.post(name: NSNotification.Name("sessionsChanged"), object: nil)
        } catch let error as NSError {
            print("Something went wrong. Error: \(error), \(error.userInfo)")
        }
        
    }

    private func removeEntry(_ session: Recording) {
        session.deleteFiles()
        self.dataContext?.delete(session)
        do {
            try self.dataContext?.save()
        } catch let error as NSError {
            print("Could not delete recording. \(error), \(error.userInfo)")
        }
    }
}
