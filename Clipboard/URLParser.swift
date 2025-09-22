//
//  URLParser.swift
//  Clipboard
//
//  Created by Tamara Osseiran on 8/29/25.
//

import Foundation
import UIKit
import CoreLocation

struct URLParser {
    
    static func parseURL(_ urlString: String) -> ParsedURL? {
        guard let url = URL(string: urlString) else { return nil }
        
        let host = url.host?.lowercased() ?? ""
        let path = url.path.lowercased()
        let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        
        // TikTok parsing
        if host.contains("tiktok.com") {
            return parseTikTokURL(url: url, path: path)
        }
        
        // Instagram parsing
        if host.contains("instagram.com") {
            return parseInstagramURL(url: url, path: path)
        }
        
        // YouTube parsing
        if host.contains("youtube.com") || host.contains("youtu.be") {
            return parseYouTubeURL(url: url, path: path, queryItems: queryItems)
        }
        
        // Google Maps parsing
        if host.contains("maps.google.com") || host.contains("goo.gl") {
            return parseGoogleMapsURL(url: url, path: path, queryItems: queryItems)
        }
        
        // Yelp parsing
        if host.contains("yelp.com") {
            return parseYelpURL(url: url, path: path)
        }
        
        // TripAdvisor parsing
        if host.contains("tripadvisor.com") {
            return parseTripAdvisorURL(url: url, path: path)
        }
        
        // Generic parsing
        return parseGenericURL(url: url, host: host, path: path)
    }
    
    // MARK: - Location Detection
    
    static func detectLocation(from urlString: String) async -> Location? {
        guard let url = URL(string: urlString) else { return nil }
        
        let host = url.host?.lowercased() ?? ""
        let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        
        // Google Maps location detection
        if host.contains("maps.google.com") || host.contains("goo.gl") {
            return await detectGoogleMapsLocation(url: url, queryItems: queryItems)
        }
        
        // TikTok location detection
        if host.contains("tiktok.com") || host.contains("vm.tiktok.com") {
            return await detectTikTokLocation(url: url)
        }
        
        // Yelp location detection
        if host.contains("yelp.com") {
            return await detectYelpLocation(url: url)
        }
        
        // TripAdvisor location detection
        if host.contains("tripadvisor.com") {
            return await detectTripAdvisorLocation(url: url)
        }
        
        // Generic location detection from URL content
        return await detectGenericLocation(from: urlString)
    }
    
    private static func detectGoogleMapsLocation(url: URL, queryItems: [URLQueryItem]) async -> Location? {
        // Extract coordinates from Google Maps URL
        if let latString = queryItems.first(where: { $0.name == "ll" })?.value,
           let coordinates = parseCoordinates(from: latString) {
            _ = queryItems.first(where: { $0.name == "q" })?.value ?? "Location"
            let address = queryItems.first(where: { $0.name == "address" })?.value
            
            return Location(
                latitude: coordinates.latitude,
                longitude: coordinates.longitude,
                address: address
            )
        }
        
        // Try to geocode the place name
        if let placeName = queryItems.first(where: { $0.name == "q" })?.value {
            return await geocodeAddress(placeName)
        }
        
        return nil
    }
    
    private static func detectTikTokLocation(url: URL) async -> Location? {
        // TikTok URLs often contain location information in the video content
        // Since we can't access the actual video content directly, we'll try to extract
        // location hints from the URL structure and query parameters
        
        let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let path = url.path.lowercased()
        
        // Check for location-related query parameters
        for item in queryItems {
            if let value = item.value?.lowercased() {
                // Look for location-related parameters
                if item.name == "location" || item.name == "place" || item.name == "venue" {
                    return await geocodeAddress(value)
                }
                
                // Check if the value contains location-like patterns
                if value.contains("restaurant") || value.contains("cafe") || value.contains("bar") ||
                   value.contains("hotel") || value.contains("shop") || value.contains("store") {
                    return await geocodeAddress(value)
                }
            }
        }
        
        // Try to extract location from path components
        let components = path.components(separatedBy: "/").filter { !$0.isEmpty }
        for component in components {
            // Skip common TikTok path components
            if component == "video" || component == "t" || component.hasPrefix("@") {
                continue
            }
            
            // Check if component looks like a location
            if component.contains("-") && component.count > 3 {
                let locationName = component.replacingOccurrences(of: "-", with: " ")
                if locationName.contains("restaurant") || locationName.contains("cafe") ||
                   locationName.contains("bar") || locationName.contains("hotel") ||
                   locationName.contains("shop") || locationName.contains("store") {
                    return await geocodeAddress(locationName)
                }
            }
        }
        
        return nil
    }
    
    private static func detectYelpLocation(url: URL) async -> Location? {
        // Extract business name from Yelp URL
        let components = url.path.components(separatedBy: "/").filter { !$0.isEmpty }
        
        if components.count >= 2 && components[0] == "biz" {
            let businessName = components[1].replacingOccurrences(of: "-", with: " ")
            
            // Try to geocode the business name
            return await geocodeAddress(businessName)
        }
        
        return nil
    }
    
    private static func detectTripAdvisorLocation(url: URL) async -> Location? {
        // Extract location from TripAdvisor URL
        let components = url.path.components(separatedBy: "/").filter { !$0.isEmpty }
        
        if components.count >= 2 {
            let locationName = components[1].replacingOccurrences(of: "-", with: " ")
            return await geocodeAddress(locationName)
        }
        
        return nil
    }
    
    private static func detectGenericLocation(from urlString: String) async -> Location? {
        // Try to extract location information from the URL or webpage content
        // This is a simplified version - in a real app, you might want to fetch the webpage
        // and extract location data from meta tags or content
        
        // For now, we'll try to extract any location-like patterns from the URL
        let locationPatterns = [
            "address=",
            "location=",
            "place=",
            "venue=",
            "city=",
            "state=",
            "country="
        ]
        
        for pattern in locationPatterns {
            if let range = urlString.range(of: pattern),
               let locationString = extractValue(from: urlString, after: range.upperBound) {
                return await geocodeAddress(locationString)
            }
        }
        
        // Try to extract location from hashtags or mentions in TikTok URLs
        if urlString.contains("tiktok.com") {
            let hashtagPattern = "#[A-Za-z0-9]+"
            if let range = urlString.range(of: hashtagPattern, options: .regularExpression) {
                let hashtag = String(urlString[range]).replacingOccurrences(of: "#", with: "")
                
                // Check if hashtag looks like a location
                if hashtag.count > 2 && !hashtag.contains("recipe") && !hashtag.contains("food") &&
                   !hashtag.contains("cooking") && !hashtag.contains("viral") {
                    return await geocodeAddress(hashtag)
                }
            }
        }
        
        return nil
    }
    
    // MARK: - Helper Methods
    
    private static func parseCoordinates(from coordinateString: String) -> CLLocationCoordinate2D? {
        let components = coordinateString.components(separatedBy: ",")
        guard components.count == 2,
              let lat = Double(components[0]),
              let lon = Double(components[1]) else {
            return nil
        }
        
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
    
    private static func extractValue(from string: String, after index: String.Index) -> String? {
        let remaining = String(string[index...])
        let components = remaining.components(separatedBy: "&")
        return components.first?.removingPercentEncoding
    }
    
    private static func geocodeAddress(_ address: String) async -> Location? {
        let geocoder = CLGeocoder()
        
        do {
            let placemarks = try await geocoder.geocodeAddressString(address)
            guard let placemark = placemarks.first,
                  let location = placemark.location else {
                return nil
            }
            
            return Location(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                address: formatAddress(from: placemark)
            )
        } catch {
            print("Geocoding error: \(error)")
            return nil
        }
    }
    
    private static func formatAddress(from placemark: CLPlacemark) -> String {
        var addressComponents: [String] = []
        
        if let thoroughfare = placemark.thoroughfare {
            addressComponents.append(thoroughfare)
        }
        if let subThoroughfare = placemark.subThoroughfare {
            addressComponents.append(subThoroughfare)
        }
        if let locality = placemark.locality {
            addressComponents.append(locality)
        }
        if let administrativeArea = placemark.administrativeArea {
            addressComponents.append(administrativeArea)
        }
        
        return addressComponents.joined(separator: ", ")
    }
    
    private static func parseTikTokURL(url: URL, path: String) -> ParsedURL? {
        // Modern TikTok URLs can be:
        // https://www.tiktok.com/@username/video/1234567890
        // https://www.tiktok.com/t/ZTd1234567890/
        // https://vm.tiktok.com/ABC123/
        // https://tiktok.com/@username/video/1234567890
        
        let components = path.components(separatedBy: "/").filter { !$0.isEmpty }
        let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        
        var title = "TikTok Video"
        var username: String?
        var tags = ["tiktok", "video"]
        
        // Parse different TikTok URL formats
        if components.count >= 3 && components[1] == "video" {
            // Format: /@username/video/1234567890
            username = components[0].replacingOccurrences(of: "@", with: "")
            title = "TikTok Video by @\(username!)"
            tags.append(username!)
        } else if components.count >= 1 && components[0].hasPrefix("t/") {
            // Format: /t/ZTd1234567890/
            title = "TikTok Video"
        } else if path.contains("@") {
            // Try to extract username from path
            let usernameMatch = path.range(of: "@[^/]+", options: .regularExpression)
            if let match = usernameMatch {
                username = String(path[match]).replacingOccurrences(of: "@", with: "")
                title = "TikTok Video by @\(username!)"
                tags.append(username!)
            }
        }
        
        // Try to extract additional info from query parameters
        if let lang = queryItems.first(where: { $0.name == "lang" })?.value {
            tags.append("lang:\(lang)")
        }
        
        // Determine content type based on URL patterns or tags
        var contentType: ContentType = .other
        let urlString = url.absoluteString.lowercased()
        
        if urlString.contains("recipe") || urlString.contains("cooking") || urlString.contains("food") {
            contentType = .recipe
            tags.append("recipe")
        } else if urlString.contains("restaurant") || urlString.contains("food") || urlString.contains("eat") {
            contentType = .restaurant
            tags.append("restaurant")
        } else if urlString.contains("travel") || urlString.contains("place") || urlString.contains("location") {
            contentType = .place
            tags.append("travel")
        } else if urlString.contains("shop") || urlString.contains("store") || urlString.contains("buy") {
            contentType = .shop
            tags.append("shop")
        } else if urlString.contains("activity") || urlString.contains("fun") || urlString.contains("experience") {
            contentType = .activity
            tags.append("activity")
        } else {
            // Default to recipe since TikTok is often used for food/recipe inspiration
            contentType = .recipe
            tags.append("inspiration")
        }
        
        return ParsedURL(
            title: title,
            description: "TikTok video\(username != nil ? " from @\(username!)" : "")",
            contentType: contentType,
            url: url.absoluteString,
            tags: tags,
            detectedLocation: nil
        )
    }
    
    private static func parseInstagramURL(url: URL, path: String) -> ParsedURL? {
        // Instagram URLs: https://www.instagram.com/p/ABC123/
        let components = path.components(separatedBy: "/").filter { !$0.isEmpty }
        
        if components.count >= 2 && components[0] == "p" {
            _ = components[1] // postId - not used but kept for future reference
            
            return ParsedURL(
                title: "Instagram Post",
                description: "Instagram post",
                contentType: .other,
                url: url.absoluteString,
                tags: ["instagram", "post"],
                detectedLocation: nil
            )
        }
        
        return nil
    }
    
    private static func parseYouTubeURL(url: URL, path: String, queryItems: [URLQueryItem]) -> ParsedURL? {
        // YouTube URLs: https://www.youtube.com/watch?v=ABC123
        let videoId = queryItems.first { $0.name == "v" }?.value
        
        if videoId != nil {
            return ParsedURL(
                title: "YouTube Video",
                description: "YouTube video",
                contentType: .recipe, // Often recipes on YouTube
                url: url.absoluteString,
                tags: ["youtube", "video"],
                detectedLocation: nil
            )
        }
        
        return nil
    }
    
    private static func parseGoogleMapsURL(url: URL, path: String, queryItems: [URLQueryItem]) -> ParsedURL? {
        // Google Maps URLs can be complex, but we can extract some info
        let placeName = queryItems.first { $0.name == "q" }?.value ?? "Location"
        
        return ParsedURL(
            title: placeName,
            description: "Location on Google Maps",
            contentType: .place,
            url: url.absoluteString,
            tags: ["google maps", "location"],
            detectedLocation: nil
        )
    }
    
    private static func parseYelpURL(url: URL, path: String) -> ParsedURL? {
        // Yelp URLs: https://www.yelp.com/biz/restaurant-name
        let components = path.components(separatedBy: "/").filter { !$0.isEmpty }
        
        if components.count >= 2 && components[0] == "biz" {
            let businessName = components[1].replacingOccurrences(of: "-", with: " ")
            
            return ParsedURL(
                title: businessName.capitalized,
                description: "Restaurant on Yelp",
                contentType: .restaurant,
                url: url.absoluteString,
                tags: ["yelp", "restaurant"],
                detectedLocation: nil
            )
        }
        
        return nil
    }
    
    private static func parseTripAdvisorURL(url: URL, path: String) -> ParsedURL? {
        // TripAdvisor URLs can be for restaurants, hotels, attractions
        let components = path.components(separatedBy: "/").filter { !$0.isEmpty }
        
        if components.count >= 2 {
            let contentType: ContentType
            if path.contains("Restaurant") {
                contentType = .restaurant
            } else if path.contains("Hotel") {
                contentType = .place
            } else {
                contentType = .activity
            }
            
            return ParsedURL(
                title: "TripAdvisor Listing",
                description: "TripAdvisor listing",
                contentType: contentType,
                url: url.absoluteString,
                tags: ["tripadvisor"],
                detectedLocation: nil
            )
        }
        
        return nil
    }
    
    private static func parseGenericURL(url: URL, host: String, path: String) -> ParsedURL? {
        // Generic parsing based on domain
        let title: String
        let description: String
        let contentType: ContentType
        var tags: [String] = []
        
        if host.contains("recipe") || host.contains("food") || host.contains("cooking") {
            title = "Recipe"
            description = "Recipe from \(host)"
            contentType = .recipe
            tags = ["recipe", "food", "cooking"]
        } else if host.contains("restaurant") || host.contains("dining") {
            title = "Restaurant"
            description = "Restaurant from \(host)"
            contentType = .restaurant
            tags = ["restaurant", "dining"]
        } else if host.contains("shop") || host.contains("store") {
            title = "Shop"
            description = "Shop from \(host)"
            contentType = .shop
            tags = ["shop", "store"]
        } else {
            title = "Link"
            description = "Link from \(host)"
            contentType = .other
            tags = ["link"]
        }
        
        return ParsedURL(
            title: title,
            description: description,
            contentType: contentType,
            url: url.absoluteString,
            tags: tags,
            detectedLocation: nil
        )
    }
}

struct ParsedURL {
    let title: String
    let description: String
    let contentType: ContentType
    let url: String
    let tags: [String]
    let detectedLocation: Location?
} 
