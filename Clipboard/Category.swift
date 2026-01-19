//
//  Category.swift
//  Clipboard
//
//  Created by Tamara Osseiran on 8/29/25.
//

import Foundation
import SwiftData

@Model
final class Category {
    var name: String = ""
    var color: String?
    var createdAt: Date = Date()
    
    init(name: String = "", color: String? = nil) {
        self.name = name
        self.color = color
        self.createdAt = Date()
    }
}
