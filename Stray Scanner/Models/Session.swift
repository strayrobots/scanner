//
//  Session.swift
//  Stray Scanner
//
//  Created by Kenneth Blomqvist on 11/15/20.
//  Copyright © 2020 Stray Robots. All rights reserved.
//

import Foundation

struct Session: Hashable, Codable, Identifiable {
    var id: Int
    var name: String
    var length: Int
    
}
