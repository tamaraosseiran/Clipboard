//
//  ContentItem.swift
//  Clipboard
//
//  Created by Tamara Osseiran on 8/29/25.
//

import Foundation
import SwiftData

@Model
final class ContentItem {
    var title: String = ""
    var itemDescription: String?
    var url: String?
    var contentTypeString: String = "Other"
    @Relationship(deleteRule: .cascade) var location: Location?
    var rating: Double?
    var isVisited: Bool = false
    var isFavorite: Bool = false
    var notes: String?
    // Store tags as a comma-separated string to avoid SwiftData array issues
    var tagsString: String = ""
    var createdAt: Date = Date()
    
    init(
        title: String,
        description: String? = nil,
        url: String? = nil,
        contentType: ContentType,
        location: Location? = nil,
        rating: Double? = nil,
        isVisited: Bool = false,
        isFavorite: Bool = false,
        notes: String? = nil,
        tags: [String] = []
    ) {
        self.title = title
        self.itemDescription = description
        self.url = url
        self.contentTypeString = contentType.rawValue
        self.location = location
        self.rating = rating
        self.isVisited = isVisited
        self.isFavorite = isFavorite
        self.notes = notes
        self.tagsString = tags.joined(separator: ",")
        self.createdAt = Date()
    }
    
    var contentTypeEnum: ContentType {
        get {
            ContentType(rawValue: contentTypeString) ?? .other
        }
        set {
            contentTypeString = newValue.rawValue
        }
    }
    
    var tags: [String] {
        get {
            tagsString.isEmpty ? [] : tagsString.components(separatedBy: ",")
        }
        set {
            tagsString = newValue.joined(separator: ",")
        }
    }
}
