//
//  ContentType.swift
//  ShareLinkExtension
//
//  ContentType enum for the share extension
//

import Foundation

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
        case .place: return "📍"
        case .recipe: return "🍳"
        case .restaurant: return "🍽️"
        case .activity: return "🎯"
        case .shop: return "🛍️"
        case .other: return "⭐"
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

