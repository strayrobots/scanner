//
//  Recording+CoreDataProperties.swift
//  StrayScanner
//
//  Created by Kenneth Blomqvist on 12/30/20.
//  Copyright © 2020 Stray Robots. All rights reserved.
//
//

import Foundation
import CoreData


extension Recording {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Recording> {
        return NSFetchRequest<Recording>(entityName: "Recording")
    }

    @NSManaged public var createdAt: Date?
    @NSManaged public var duration: Double
    @NSManaged public var name: String?
    @NSManaged public var id: UUID?
    @NSManaged public var rgbFilePath: URL?
    @NSManaged public var depthFilePath: URL?

}

extension Recording : Identifiable {

}
