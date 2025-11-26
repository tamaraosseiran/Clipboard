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
    var title: String
    var itemDescription: String?
    var url: String?
    var contentTypeString: String // Store as string for SwiftData
    var location: Location?
    var rating: Double?
    var isVisited: Bool
    var isFavorite: Bool
    var notes: String?
    var tags: [String]
    var createdAt: Date
    
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
        self.tags = tags
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
}
