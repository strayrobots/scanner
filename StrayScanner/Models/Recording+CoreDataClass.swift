//
//  Recording+CoreDataClass.swift
//  StrayScanner
//
//  Created by Kenneth Blomqvist on 12/29/20.
//  Copyright © 2020 Stray Robots. All rights reserved.
//
//

import Foundation
import CoreData

@objc(Recording)
public class Recording: NSManagedObject {

    func deleteFiles() {
        deleteFile(self.rgbFilePath)
        deleteFile(self.depthFilePath)

    }

    private func deleteFile(_ path: URL?) {
        if let filePath = path {
            if FileManager.default.fileExists(atPath: filePath.absoluteString) {
                do {
                    try FileManager.default.removeItem(atPath: filePath.absoluteString)
                } catch let error as NSError {
                    print("Could not delete file \(filePath.absoluteString). \(error), \(error.userInfo)")
                }
            }
        }
    }

}
