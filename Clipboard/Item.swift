//
//  Item.swift
//  Clipboard
//
//  Created by Tamara Osseiran on 8/29/25.
//

import Foundation
import SwiftData
import CoreLocation

// MARK: - Content Types
enum ContentType: String, CaseIterable, Codable {
    case place = "Place"
    case recipe = "Recipe"
    case restaurant = "Restaurant"
    case activity = "Activity"
    case shop = "Shop"
    case other = "Other"
    
    var icon: String {
        switch self {
        case .place: return "mappin.circle.fill"
        case .recipe: return "fork.knife.circle.fill"
        case .restaurant: return "building.2.crop.circle.fill"
        case .activity: return "figure.hiking.circle.fill"
        case .shop: return "bag.circle.fill"
        case .other: return "star.circle.fill"
        }
    }
    
    var color: String {
        switch self {
        case .place: return "blue"
        case .recipe: return "orange"
        case .restaurant: return "red"
        case .activity: return "green"
        case .shop: return "purple"
        case .other: return "gray"
        }
    }
}

// MARK: - Location Model
@Model
final class Location {
    var latitude: Double
    var longitude: Double
    var address: String?
    var city: String?
    var state: String?
    var country: String?
    
    init(latitude: Double, longitude: Double, address: String? = nil, city: String? = nil, state: String? = nil, country: String? = nil) {
        self.latitude = latitude
        self.longitude = longitude
        self.address = address
        self.city = city
        self.state = state
        self.country = country
    }
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    var displayAddress: String {
        var components: [String] = []
        if let address = address { components.append(address) }
        if let city = city { components.append(city) }
        if let state = state { components.append(state) }
        if let country = country { components.append(country) }
        return components.joined(separator: ", ")
    }
}

// MARK: - Category Model
@Model
final class Category {
    var name: String
    var color: String
    var icon: String
    var items: [ContentItem]?
    
    init(name: String, color: String = "blue", icon: String = "tag.circle.fill") {
        self.name = name
        self.color = color
        self.icon = icon
    }
}

// MARK: - Main Content Item Model
@Model
final class ContentItem {
    var id: UUID
    var title: String
    var itemDescription: String?
    var url: String?
    var contentType: String // ContentType.rawValue
    var location: Location?
    var category: Category?
    var rating: Int? // 1-5 stars
    var isVisited: Bool
    var isFavorite: Bool
    var notes: String?
    var createdAt: Date
    var updatedAt: Date
    var tags: [String]
    
    init(title: String, 
         description: String? = nil, 
         url: String? = nil, 
         contentType: ContentType = .other,
         location: Location? = nil,
         category: Category? = nil,
         rating: Int? = nil,
         isVisited: Bool = false,
         isFavorite: Bool = false,
         notes: String? = nil,
         tags: [String] = []) {
        self.id = UUID()
        self.title = title
        self.itemDescription = description
        self.url = url
        self.contentType = contentType.rawValue
        self.location = location
        self.category = category
        self.rating = rating
        self.isVisited = isVisited
        self.isFavorite = isFavorite
        self.notes = notes
        self.createdAt = Date()
        self.updatedAt = Date()
        self.tags = tags
    }
    
    var contentTypeEnum: ContentType {
        ContentType(rawValue: contentType) ?? .other
    }
    
    var displayLocation: String {
        if let location = location {
            return location.displayAddress
        }
        return "No location"
    }
    
    var ratingText: String {
        if let rating = rating {
            return "\(rating)/5"
        }
        return "Not rated"
    }
    
    var statusText: String {
        if isVisited {
            return "Visited"
        }
        return "Not visited"
    }
}
