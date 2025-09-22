//
//  URLParser.swift
//  Clipboard
//
//  Created by Tamara Osseiran on 8/29/25.
//

import Foundation
import CoreLocation

struct URLParser {
    static func parseURL(_ url: URL) -> ParsedURL {
        let urlString = url.absoluteString.lowercased()
        let path = url.path
        
        // TikTok URLs
        if urlString.contains("tiktok.com") || urlString.contains("vm.tiktok.com") {
            return parseTikTokURL(url: url, path: path)
        }
        
        // Instagram URLs
        if urlString.contains("instagram.com") {
            return parseInstagramURL(url: url, path: path)
        }
        
        // YouTube URLs
        if urlString.contains("youtube.com") || urlString.contains("youtu.be") {
            return parseYouTubeURL(url: url, path: path)
        }
        
        // Google Maps URLs
        if urlString.contains("maps.google.com") || urlString.contains("goo.gl/maps") {
            return parseGoogleMapsURL(url: url, path: path)
        }
        
        // Yelp URLs
        if urlString.contains("yelp.com") {
            return parseYelpURL(url: url, path: path)
        }
        
        // TripAdvisor URLs
        if urlString.contains("tripadvisor.com") {
            return parseTripAdvisorURL(url: url, path: path)
        }
        
        // Generic URL parsing
        return parseGenericURL(url: url, path: path)
    }
    
    // MARK: - TikTok Parsing
    private static func parseTikTokURL(url: URL, path: String) -> ParsedURL {
        let components = path.components(separatedBy: "/").filter { !$0.isEmpty }
        let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        
        var title = "TikTok Video"
        var username: String?
        var videoId: String?
        var tags = ["tiktok", "video"]
        var description = "TikTok video"
        
        // Parse different TikTok URL formats
        if components.count >= 3 && components[1] == "video" {
            // Format: /@username/video/1234567890
            username = components[0].replacingOccurrences(of: "@", with: "")
            videoId = components[2]
            title = "TikTok Video by @\(username!)"
            description = "TikTok video from @\(username!)"
            tags.append(username!)
        } else if components.count >= 1 && components[0].hasPrefix("t/") {
            // Format: /t/ZTd1234567890/
            videoId = String(components[0].dropFirst(2))
            title = "TikTok Video"
        } else if path.contains("@") {
            // Try to extract username from path
            let usernameMatch = path.range(of: "@[^/]+", options: .regularExpression)
            if let match = usernameMatch {
                username = String(path[match]).replacingOccurrences(of: "@", with: "")
                title = "TikTok Video by @\(username!)"
                description = "TikTok video from @\(username!)"
                tags.append(username!)
            }
        }
        
        // Try to extract additional info from query parameters
        if let lang = queryItems.first(where: { $0.name == "lang" })?.value {
            tags.append("lang:\(lang)")
        }
        
        // Determine content type based on URL patterns, hashtags, or common TikTok content
        var contentType: ContentType = .other
        let urlString = url.absoluteString.lowercased()
        
        // Check for specific content indicators
        if urlString.contains("recipe") || urlString.contains("cooking") || urlString.contains("food") || 
           urlString.contains("kitchen") || urlString.contains("chef") {
            contentType = .recipe
            tags.append("recipe")
            tags.append("cooking")
        } else if urlString.contains("restaurant") || urlString.contains("food") || urlString.contains("eat") ||
                  urlString.contains("dining") || urlString.contains("cafe") || urlString.contains("bar") {
            contentType = .restaurant
            tags.append("restaurant")
            tags.append("food")
        } else if urlString.contains("travel") || urlString.contains("place") || urlString.contains("location") ||
                  urlString.contains("visit") || urlString.contains("destination") {
            contentType = .place
            tags.append("travel")
            tags.append("place")
        } else if urlString.contains("shop") || urlString.contains("store") || urlString.contains("buy") ||
                  urlString.contains("shopping") || urlString.contains("mall") {
            contentType = .shop
            tags.append("shop")
            tags.append("shopping")
        } else if urlString.contains("activity") || urlString.contains("fun") || urlString.contains("experience") ||
                  urlString.contains("event") || urlString.contains("entertainment") {
            contentType = .activity
            tags.append("activity")
            tags.append("fun")
        } else {
            // Default to recipe since TikTok is often used for food/recipe inspiration
            contentType = .recipe
            tags.append("inspiration")
        }
        
        // Try to detect location from TikTok content
        let detectedLocation = detectTikTokLocation(url: url)
        
        return ParsedURL(
            title: title,
            description: description,
            contentType: contentType,
            url: url.absoluteString,
            tags: tags,
            detectedLocation: detectedLocation
        )
    }
    
    // MARK: - Instagram Parsing
    private static func parseInstagramURL(url: URL, path: String) -> ParsedURL {
        let components = path.components(separatedBy: "/").filter { !$0.isEmpty }
        
        var title = "Instagram Post"
        var username: String?
        var postId: String?
        var tags = ["instagram", "post"]
        
        if components.count >= 2 && components[0] == "p" {
            // Format: /p/ABC123/
            postId = components[1]
            title = "Instagram Post"
        } else if components.count >= 1 && components[0].hasPrefix("@") {
            // Format: /@username/
            username = String(components[0].dropFirst())
            title = "Instagram Profile: @\(username!)"
            tags.append(username!)
        }
        
        // Determine content type
        let urlString = url.absoluteString.lowercased()
        var contentType: ContentType = .other
        
        if urlString.contains("food") || urlString.contains("recipe") || urlString.contains("cooking") {
            contentType = .recipe
        } else if urlString.contains("restaurant") || urlString.contains("dining") {
            contentType = .restaurant
        } else if urlString.contains("travel") || urlString.contains("place") {
            contentType = .place
        } else if urlString.contains("shop") || urlString.contains("store") {
            contentType = .shop
        } else if urlString.contains("activity") || urlString.contains("event") {
            contentType = .activity
        }
        
        return ParsedURL(
            title: title,
            description: "Instagram post\(username != nil ? " from @\(username!)" : "")",
            contentType: contentType,
            url: url.absoluteString,
            tags: tags,
            detectedLocation: nil
        )
    }
    
    // MARK: - YouTube Parsing
    private static func parseYouTubeURL(url: URL, path: String) -> ParsedURL {
        let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let videoId = queryItems.first(where: { $0.name == "v" })?.value ?? 
                     path.components(separatedBy: "/").last
        
        var title = "YouTube Video"
        var tags = ["youtube", "video"]
        
        if let id = videoId {
            title = "YouTube Video (\(id))"
            tags.append(id)
        }
        
        // Determine content type
        let urlString = url.absoluteString.lowercased()
        var contentType: ContentType = .other
        
        if urlString.contains("recipe") || urlString.contains("cooking") || urlString.contains("food") {
            contentType = .recipe
        } else if urlString.contains("restaurant") || urlString.contains("food") {
            contentType = .restaurant
        } else if urlString.contains("travel") || urlString.contains("place") {
            contentType = .place
        } else if urlString.contains("shop") || urlString.contains("store") {
            contentType = .shop
        } else if urlString.contains("activity") || urlString.contains("event") {
            contentType = .activity
        }
        
        return ParsedURL(
            title: title,
            description: "YouTube video",
            contentType: contentType,
            url: url.absoluteString,
            tags: tags,
            detectedLocation: nil
        )
    }
    
    // MARK: - Google Maps Parsing
    private static func parseGoogleMapsURL(url: URL, path: String) -> ParsedURL {
        let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        
        var title = "Google Maps Location"
        var address: String?
        var tags = ["google", "maps", "location"]
        
        // Try to extract location name from query parameters
        if let q = queryItems.first(where: { $0.name == "q" })?.value {
            title = q
            address = q
        }
        
        // Try to extract from path
        if path.contains("/place/") {
            let components = path.components(separatedBy: "/")
            if let placeIndex = components.firstIndex(of: "place") {
                let placeName = components[placeIndex + 1].replacingOccurrences(of: "+", with: " ")
                title = placeName
                address = placeName
            }
        }
        
        return ParsedURL(
            title: title,
            description: "Google Maps location",
            contentType: .place,
            url: url.absoluteString,
            tags: tags,
            detectedLocation: address != nil ? Location(latitude: 0, longitude: 0, address: address!) : nil
        )
    }
    
    // MARK: - Yelp Parsing
    private static func parseYelpURL(url: URL, path: String) -> ParsedURL {
        let components = path.components(separatedBy: "/").filter { !$0.isEmpty }
        
        var title = "Yelp Business"
        var tags = ["yelp", "business"]
        
        if components.count >= 2 && components[0] == "biz" {
            let businessName = components[1].replacingOccurrences(of: "-", with: " ")
            title = businessName
            tags.append(businessName)
        }
        
        return ParsedURL(
            title: title,
            description: "Yelp business listing",
            contentType: .restaurant,
            url: url.absoluteString,
            tags: tags,
            detectedLocation: nil
        )
    }
    
    // MARK: - TripAdvisor Parsing
    private static func parseTripAdvisorURL(url: URL, path: String) -> ParsedURL {
        let components = path.components(separatedBy: "/").filter { !$0.isEmpty }
        
        var title = "TripAdvisor Listing"
        var tags = ["tripadvisor", "travel"]
        
        if components.count >= 2 && components[0] == "Restaurant_Review" {
            let restaurantName = components[1].replacingOccurrences(of: "-", with: " ")
            title = restaurantName
            tags.append(restaurantName)
        }
        
        return ParsedURL(
            title: title,
            description: "TripAdvisor listing",
            contentType: .restaurant,
            url: url.absoluteString,
            tags: tags,
            detectedLocation: nil
        )
    }
    
    // MARK: - Generic URL Parsing
    private static func parseGenericURL(url: URL, path: String) -> ParsedURL {
        let domain = url.host ?? "Unknown"
        let title = domain.replacingOccurrences(of: "www.", with: "")
        
        return ParsedURL(
            title: title,
            description: "Web page from \(domain)",
            contentType: .other,
            url: url.absoluteString,
            tags: ["web", "link"],
            detectedLocation: nil
        )
    }
    
    // MARK: - Location Detection
    private static func detectTikTokLocation(url: URL) -> Location? {
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
                    return geocodeAddress(value)
                }
                
                // Check if the value contains location-like patterns
                if value.contains("restaurant") || value.contains("cafe") || value.contains("bar") ||
                   value.contains("hotel") || value.contains("shop") || value.contains("store") {
                    return geocodeAddress(value)
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
                    return geocodeAddress(locationName)
                }
            }
        }
        
        return nil
    }
    
    private static func geocodeAddress(_ address: String) -> Location? {
        // In a real implementation, you would use CoreLocation's geocoding
        // For now, we'll return a placeholder location
        return Location(latitude: 0, longitude: 0, address: address)
    }
}

// MARK: - ParsedURL Model
struct ParsedURL {
    let title: String
    let description: String
    let contentType: ContentType
    let url: String
    let tags: [String]
    let detectedLocation: Location?
}
