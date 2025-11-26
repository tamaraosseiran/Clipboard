//
//  ContentType.swift
//  Clipboard
//
//  Created by Tamara Osseiran on 8/29/25.
//

import Foundation
import SwiftUI

enum ContentType: String, CaseIterable, Codable {
    case restaurant = "Restaurant"
    case shop = "Shop"
    case activity = "Activity"
    case recipe = "Recipe"
    case place = "Place"
    case other = "Other"
    
    var icon: String {
        switch self {
        case .restaurant:
            return "🍽️"
        case .shop:
            return "🛍️"
        case .activity:
            return "🎯"
        case .recipe:
            return "📝"
        case .place:
            return "📍"
        case .other:
            return "📌"
        }
    }
    
    var color: String {
        switch self {
        case .restaurant:
            return "orange"
        case .shop:
            return "blue"
        case .activity:
            return "purple"
        case .recipe:
            return "green"
        case .place:
            return "red"
        case .other:
            return "gray"
        }
    }
}
