//
//  URLParser.swift
//  Clipboard
//
//  Created by Tamara Osseiran on 8/29/25.
//

import Foundation
import CoreLocation

struct ParsedURL {
    let title: String
    let description: String
    let contentType: ContentType
    let detectedLocation: Location?
    let tags: [String]
}

struct URLParser {
    static func parseURL(_ url: URL) -> ParsedURL {
        let host = url.host ?? ""
        let path = url.path
        
        // Extract title from URL
        var title = host
        if !path.isEmpty && path != "/" {
            let pathComponents = path.components(separatedBy: "/").filter { !$0.isEmpty }
            if let lastComponent = pathComponents.last {
                title = lastComponent.replacingOccurrences(of: "-", with: " ").capitalized
            }
        }
        
        // Determine content type based on domain
        let contentType: ContentType
        let lowercasedHost = host.lowercased()
        if lowercasedHost.contains("yelp") || lowercasedHost.contains("opentable") || lowercasedHost.contains("resy") {
            contentType = .restaurant
        } else if lowercasedHost.contains("tiktok") || lowercasedHost.contains("instagram") || lowercasedHost.contains("youtube") {
            contentType = .other
        } else if lowercasedHost.contains("maps.google") || lowercasedHost.contains("apple.com/maps") {
            contentType = .place
        } else if lowercasedHost.contains("shop") || lowercasedHost.contains("store") {
            contentType = .shop
        } else {
            contentType = .place
        }
        
        // Try to extract location from URL (for Google Maps, Apple Maps, etc.)
        var detectedLocation: Location? = nil
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let queryItems = components.queryItems {
            
            // Check for coordinates in query parameters
            if let latString = queryItems.first(where: { $0.name == "q" || $0.name == "ll" })?.value,
               let lat = Double(latString) {
                // Try to find longitude
                if let lonString = queryItems.first(where: { $0.name == "lon" || $0.name == "lng" })?.value,
                   let lon = Double(lonString) {
                    detectedLocation = Location(latitude: lat, longitude: lon, address: nil)
                }
            }
            
            // Check for place name in query
            if detectedLocation == nil,
               let placeName = queryItems.first(where: { $0.name == "q" })?.value {
                detectedLocation = Location(latitude: 0.0, longitude: 0.0, address: placeName)
            }
        }
        
        // Extract tags from URL path or domain
        var tags: [String] = []
        if lowercasedHost.contains("coffee") || lowercasedHost.contains("cafe") {
            tags.append("coffee")
        }
        if lowercasedHost.contains("restaurant") || lowercasedHost.contains("dining") {
            tags.append("dining")
        }
        
        let description = "Shared from \(host)"
        
        return ParsedURL(
            title: title.isEmpty ? "Shared Link" : title,
            description: description,
            contentType: contentType,
            detectedLocation: detectedLocation,
            tags: tags
        )
    }
}
