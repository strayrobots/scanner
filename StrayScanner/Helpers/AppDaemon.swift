//
//  AppDaemon.swift
//  StrayScanner
//
//  Created by Kenneth Blomqvist on 1/17/21.
//  Copyright © 2021 Stray Robots. All rights reserved.
//

import Foundation
import CoreData

@MainActor
final class AppDaemon {
    private let dataContext: NSManagedObjectContext

    init(dataContext: NSManagedObjectContext) {
        self.dataContext = dataContext
    }

    /// Removes the entries whose dataset folder is gone from the device.
    /// Folders are removed through Finder or the Files app, which is the main way datasets are exported.
    func removeDeletedEntries() {
        let request = Recording.fetchRequest()
        do {
            let removed = try dataContext.fetch(request).filter { session in
                guard let path = session.absoluteRgbPath() else {
                    print("Session \(session) does not have an rgb file.")
                    return false
                }
                return !FileManager.default.fileExists(atPath: path.deletingLastPathComponent().path)
            }
            guard !removed.isEmpty else { return }
            print("\(removed.count) dataset folder(s) have been removed.")
            removed.forEach { session in
                session.deleteFiles()
                dataContext.delete(session)
            }
            try dataContext.save()
        } catch let error as NSError {
            print("Could not remove deleted entries. \(error), \(error.userInfo)")
        }
    }
}
