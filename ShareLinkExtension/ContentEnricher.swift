//
//  ContentEnricher.swift
//  ShareLinkExtension
//
//  Smart content enrichment for shared URLs and text.
//  Extracts place names, suggests categories, and resolves locations.
//

import Foundation
import MapKit
import NaturalLanguage
import OSLog

// MARK: - Enriched Content Result

struct EnrichedContent {
    var name: String
    var notes: String?
    var suggestedCategory: ContentType
    var categoryConfidence: CategoryConfidence
    var primaryPlace: ResolvedPlace?
    var alternatePlaces: [ResolvedPlace]
    var sourceURL: String?
    var extractedKeywords: [String]
    
    enum CategoryConfidence {
        case high    // Strong keyword match or structured data
        case medium  // Partial match or inferred
        case low     // Default/fallback
    }
}

struct ResolvedPlace {
    var name: String
    var address: String
    var latitude: Double
    var longitude: Double
    var category: String?  // From MapKit (e.g., "Restaurant", "Cafe")
    var phoneNumber: String?
    var website: URL?
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

// MARK: - Content Enricher

enum ContentEnricher {
    
    private static let logger = Logger(subsystem: "com.tamaraosseiran.clipboard.share", category: "ContentEnricher")
    
    // MARK: - Main Entry Point
    
    /// Enriches shared content by extracting meaningful information and resolving places
    static func enrich(
        url: URL?,
        text: String?,
        htmlTitle: String?,
        htmlDescription: String?,
        structuredAddress: String?,
        structuredCoordinates: (lat: Double, lon: Double)?,
        completion: @escaping (EnrichedContent) -> Void
    ) {
        logger.info("Starting content enrichment")
        
        // Step 1: Detect source platform and extract content accordingly
        let sourceType = detectSourceType(url: url)
        logger.info("Detected source type: \(sourceType.rawValue)")
        
        // Step 2: Extract the best name and notes from available data
        let (extractedName, extractedNotes) = extractNameAndNotes(
            url: url,
            text: text,
            htmlTitle: htmlTitle,
            htmlDescription: htmlDescription,
            sourceType: sourceType
        )
        
        // Step 3: Extract business name and address separately
        let allText = [extractedName, extractedNotes, text, htmlTitle, htmlDescription]
            .compactMap { $0 }
            .joined(separator: " ")
        
        // Extract business name (if not already extracted)
        var businessName = extractedName
        if businessName == "Shared Spot" || businessName.isEmpty {
            if let extractedBusinessName = extractBusinessName(from: allText) {
                businessName = extractedBusinessName
                logger.info("Extracted business name: \(businessName)")
            }
        }
        
        // Extract address from text (look for addresses, location pins, etc.)
        var extractedAddress: String? = nil
        let addressPatterns = [
            // Location pin with address: "📍 4205 Buena Vista"
            #"📍\s*([0-9]+\s+[A-Za-z0-9\s]+)"#,
            // Standard address pattern: "4205 Buena Vista St"
            #"\b([0-9]+\s+[A-Za-z0-9\s]+(?:St|Street|Ave|Avenue|Rd|Road|Blvd|Boulevard|Dr|Drive|Ln|Lane|Way|Ct|Court|Pl|Place))\b"#,
        ]
        
        for pattern in addressPatterns {
            if let match = firstMatch(in: allText, pattern: pattern) {
                let cleaned = match.trimmingCharacters(in: .whitespacesAndNewlines)
                if cleaned.count >= 5 && cleaned.prefix(1).allSatisfy({ $0.isNumber }) {
                    extractedAddress = cleaned
                    logger.info("Extracted address: \(extractedAddress ?? "nil")")
                    break
                }
            }
        }
        
        // Also use NSDataDetector for addresses
        if extractedAddress == nil {
            if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.address.rawValue) {
                let range = NSRange(allText.startIndex..., in: allText)
                let matches = detector.matches(in: allText, options: [], range: range)
                if let firstMatch = matches.first,
                   let swiftRange = Range(firstMatch.range, in: allText) {
                    extractedAddress = String(allText[swiftRange])
                    logger.info("Extracted address via NSDataDetector: \(extractedAddress ?? "nil")")
                }
            }
        }
        
        // Extract location hint for search refinement
        let textForNLP = text ?? extractedNotes ?? ""
        var locationHint: String? = nil
        
        if !textForNLP.isEmpty {
            if let nlpEntities = extractEntitiesUsingNLP(from: textForNLP) {
                // Use NLP places as location hint (cities, not business names)
                let cityHints = nlpEntities.allPlaces.filter { place in
                    // Exclude if it matches the business name
                    if !businessName.isEmpty {
                        return !place.lowercased().contains(businessName.lowercased()) &&
                               !businessName.lowercased().contains(place.lowercased())
                    }
                    return true
                }
                
                if let cityHint = cityHints.first {
                    locationHint = cityHint
                    logger.info("NLP location hint: \(cityHint)")
                }
            }
        }
        
        // Fall back to pattern-based location hint extraction
        if locationHint == nil {
            locationHint = extractLocationHint(from: text ?? "") ?? extractLocationHint(from: extractedNotes ?? "")
        }
        logger.info("Final location hint: \(locationHint ?? "none")")
        
        // Step 4: Detect category from content
        let (category, confidence, keywords) = detectCategory(
            name: extractedName,
            notes: extractedNotes,
            text: allText,
            url: url
        )
        logger.info("Detected category: \(category.rawValue) with confidence: \(String(describing: confidence))")
        
        // Step 5: Resolve place location
        if let address = structuredAddress, !address.isEmpty {
            // We have a structured address - use it directly
            logger.info("Using structured address: \(address)")
            
            if let coords = structuredCoordinates {
                let place = ResolvedPlace(
                    name: extractedName,
                    address: address,
                    latitude: coords.lat,
                    longitude: coords.lon,
                    category: nil,
                    phoneNumber: nil,
                    website: nil
                )
                
                let result = EnrichedContent(
                    name: extractedName,
                    notes: extractedNotes,
                    suggestedCategory: category,
                    categoryConfidence: confidence,
                    primaryPlace: place,
                    alternatePlaces: [],
                    sourceURL: url?.absoluteString,
                    extractedKeywords: keywords
                )
                completion(result)
            } else {
                // Geocode the address
                geocodeAddress(address) { place in
                    var resolvedPlace = place
                    resolvedPlace?.name = extractedName
                    
                    let result = EnrichedContent(
                        name: extractedName,
                        notes: extractedNotes,
                        suggestedCategory: category,
                        categoryConfidence: confidence,
                        primaryPlace: resolvedPlace,
                        alternatePlaces: [],
                        sourceURL: url?.absoluteString,
                        extractedKeywords: keywords
                    )
                    completion(result)
                }
            }
        } else {
            // Smart place resolution: connect business name with address
            resolvePlaceWithNameAndAddress(
                businessName: businessName,
                address: extractedAddress,
                locationHint: locationHint,
                extractedName: extractedName,
                extractedNotes: extractedNotes,
                category: category,
                confidence: confidence,
                keywords: keywords,
                url: url,
                completion: completion
            )
        }
    }
    
    // MARK: - Smart Place Resolution
    
    /// Intelligently connects business names with addresses
    /// - If we have business name but no address: search for name, get address from result
    /// - If we have address but no business name: search for address, get name from result
    /// - If we have both: search with both for best match
    private static func resolvePlaceWithNameAndAddress(
        businessName: String,
        address: String?,
        locationHint: String?,
        extractedName: String,
        extractedNotes: String?,
        category: ContentType,
        confidence: EnrichedContent.CategoryConfidence,
        keywords: [String],
        url: URL?,
        completion: @escaping (EnrichedContent) -> Void
    ) {
        let hasBusinessName = !businessName.isEmpty && businessName != "Shared Spot"
        let hasAddress = address != nil && !address!.isEmpty
        
        logger.info("🔍 Smart place resolution:")
        logger.info("   Business name: \(hasBusinessName ? businessName : "none")")
        logger.info("   Address: \(hasAddress ? address! : "none")")
        logger.info("   Location hint: \(locationHint ?? "none")")
        
        if hasBusinessName && hasAddress {
            // We have both - search with both for best match
            var searchQuery = "\(businessName) \(address!)"
            if let hint = locationHint {
                searchQuery = "\(searchQuery), \(hint)"
            }
            logger.info("   Strategy: Search with both name and address")
            logger.info("   Query: \(searchQuery)")
            
            searchPlaces(query: searchQuery, near: nil) { places in
                // Use business name from search result if available, otherwise use extracted
                let finalName = places.first?.name ?? businessName
                let result = EnrichedContent(
                    name: finalName,
                    notes: extractedNotes,
                    suggestedCategory: category,
                    categoryConfidence: confidence,
                    primaryPlace: places.first,
                    alternatePlaces: Array(places.dropFirst().prefix(3)),
                    sourceURL: url?.absoluteString,
                    extractedKeywords: keywords
                )
                completion(result)
            }
        } else if hasBusinessName {
            // We have business name but no address - search for name, get address from result
            var searchQuery = businessName
            if let hint = locationHint {
                searchQuery = "\(searchQuery), \(hint)"
            }
            logger.info("   Strategy: Search for business name to get address")
            logger.info("   Query: \(searchQuery)")
            
            searchPlaces(query: searchQuery, near: nil) { places in
                // Use business name from search result if it's better, otherwise use extracted
                let finalName = places.first?.name ?? businessName
                let result = EnrichedContent(
                    name: finalName,
                    notes: extractedNotes,
                    suggestedCategory: category,
                    categoryConfidence: confidence,
                    primaryPlace: places.first, // This will have the address
                    alternatePlaces: Array(places.dropFirst().prefix(3)),
                    sourceURL: url?.absoluteString,
                    extractedKeywords: keywords
                )
                completion(result)
            }
        } else if hasAddress {
            // We have address but no business name - search for address, get name from result
            var searchQuery = address!
            if let hint = locationHint {
                searchQuery = "\(searchQuery), \(hint)"
            }
            logger.info("   Strategy: Search for address to get business name")
            logger.info("   Query: \(searchQuery)")
            
            searchPlaces(query: searchQuery, near: nil) { places in
                // Use business name from search result
                let finalName = places.first?.name ?? extractedName
                let result = EnrichedContent(
                    name: finalName,
                    notes: extractedNotes,
                    suggestedCategory: category,
                    categoryConfidence: confidence,
                    primaryPlace: places.first,
                    alternatePlaces: Array(places.dropFirst().prefix(3)),
                    sourceURL: url?.absoluteString,
                    extractedKeywords: keywords
                )
                completion(result)
            }
        } else {
            // No business name or address - try generic search with extracted name
            var searchQuery = extractedName
            if let hint = locationHint {
                searchQuery = "\(searchQuery), \(hint)"
            }
            logger.info("   Strategy: Generic search with extracted name")
            logger.info("   Query: \(searchQuery)")
            
            searchPlaces(query: searchQuery, near: nil) { places in
                let result = EnrichedContent(
                    name: extractedName,
                    notes: extractedNotes,
                    suggestedCategory: category,
                    categoryConfidence: confidence,
                    primaryPlace: places.first,
                    alternatePlaces: Array(places.dropFirst().prefix(3)),
                    sourceURL: url?.absoluteString,
                    extractedKeywords: keywords
                )
                completion(result)
            }
        }
    }
    
    // MARK: - Source Type Detection
    
    enum SourceType: String {
        case tiktok = "TikTok"
        case instagram = "Instagram"
        case youtube = "YouTube"
        case yelp = "Yelp"
        case googleMaps = "Google Maps"
        case appleMaps = "Apple Maps"
        case twitter = "Twitter/X"
        case reddit = "Reddit"
        case facebook = "Facebook"
        case generic = "Web"
    }
    
    private static func detectSourceType(url: URL?) -> SourceType {
        guard let host = url?.host?.lowercased() else { return .generic }
        
        if host.contains("tiktok") || host.contains("vm.tiktok") {
            return .tiktok
        } else if host.contains("instagram") {
            return .instagram
        } else if host.contains("youtube") || host.contains("youtu.be") {
            return .youtube
        } else if host.contains("yelp") {
            return .yelp
        } else if host.contains("google") && (host.contains("maps") || url?.path.contains("/maps") == true) {
            return .googleMaps
        } else if host.contains("apple") && host.contains("maps") {
            return .appleMaps
        } else if host.contains("twitter") || host.contains("x.com") {
            return .twitter
        } else if host.contains("reddit") {
            return .reddit
        } else if host.contains("facebook") || host.contains("fb.com") {
            return .facebook
        }
        
        return .generic
    }
    
    // MARK: - Name and Notes Extraction
    
    private static func extractNameAndNotes(
        url: URL?,
        text: String?,
        htmlTitle: String?,
        htmlDescription: String?,
        sourceType: SourceType
    ) -> (name: String, notes: String?) {
        
        var name = "Shared Spot"
        var notes: String? = nil
        
        logger.info("extractNameAndNotes - sourceType: \(sourceType.rawValue)")
        logger.info("extractNameAndNotes - text: \(text ?? "nil")")
        logger.info("extractNameAndNotes - htmlTitle: \(htmlTitle ?? "nil")")
        
        switch sourceType {
        case .tiktok:
            // TikTok shares ONLY the URL - no caption in the share data
            // The caption comes from oEmbed API and is passed as htmlDescription
            logger.info("TikTok - htmlDescription (oEmbed caption): \(htmlDescription ?? "nil")")
            logger.info("TikTok - text: \(text ?? "nil")")
            
            // Prioritize oEmbed caption (htmlDescription) since TikTok doesn't share text
            let captionSource = htmlDescription ?? text
            
            if let caption = captionSource, !caption.isEmpty {
                logger.info("TikTok - processing caption: \(caption.prefix(200))")
                
                // First, try to extract business name (not address) from the caption
                let businessName = extractBusinessName(from: caption)
                logger.info("TikTok - extracted business name: \(businessName ?? "nil")")
                
                // If we found a business name, use it; otherwise try place name extraction
                if let businessName = businessName {
                    name = businessName
                } else {
                    let placeName = extractPlaceNameFromCaption(caption)
                    logger.info("TikTok - extracted place name: \(placeName ?? "nil")")
                    name = placeName ?? cleanCaption(caption)
                }
                notes = caption
            } else if let text = text, !text.isEmpty {
                logger.info("TikTok - fallback to text: \(text.prefix(200))")
                let (caption, _) = extractCaptionAndURL(from: text)
                logger.info("TikTok - extracted caption: \(caption ?? "nil")")
                
                if let caption = caption, !caption.isEmpty {
                    // Try to extract business name first
                    let businessName = extractBusinessName(from: caption)
                    if let businessName = businessName {
                        name = businessName
                    } else {
                        let placeName = extractPlaceNameFromCaption(caption)
                        logger.info("TikTok - extracted place name: \(placeName ?? "nil")")
                        name = placeName ?? cleanCaption(caption)
                    }
                    notes = caption
                } else {
                    // The entire text might be the caption (no URL extracted)
                    // This happens when TikTok shares text and URL separately
                    let businessName = extractBusinessName(from: text)
                    if let businessName = businessName {
                        name = businessName
                        notes = text
                    } else {
                        let placeName = extractPlaceNameFromCaption(text)
                        if let placeName = placeName {
                            name = placeName
                            notes = text
                        } else if !text.lowercased().contains("tiktok") {
                            // Use the text as caption if it doesn't look like a URL
                            name = cleanCaption(text)
                            notes = text
                        }
                    }
                }
            }
            
            // Fall back to HTML title if we still have default name
            if name == "Shared Spot" {
                if let htmlTitle = htmlTitle, !isGenericTitle(htmlTitle, for: .tiktok) {
                    name = cleanTitle(htmlTitle, for: .tiktok)
                }
            }
            
        case .instagram:
            // Instagram shares may have caption in text
            if let text = text {
                let (caption, _) = extractCaptionAndURL(from: text)
                if let caption = caption, !caption.isEmpty {
                    // Try to extract business name first
                    let businessName = extractBusinessName(from: caption)
                    if let businessName = businessName {
                        name = businessName
                    } else {
                        let placeName = extractPlaceNameFromCaption(caption)
                        name = placeName ?? cleanCaption(caption)
                    }
                    notes = caption
                }
            } else if let htmlTitle = htmlTitle, !isGenericTitle(htmlTitle, for: .instagram) {
                name = cleanTitle(htmlTitle, for: .instagram)
            }
            
        case .yelp:
            // Yelp titles are usually good - "Business Name - Yelp"
            if let htmlTitle = htmlTitle {
                name = cleanTitle(htmlTitle, for: .yelp)
            }
            if let htmlDescription = htmlDescription {
                notes = htmlDescription
            }
            
        case .googleMaps:
            // Google Maps usually has good structured data
            if let htmlTitle = htmlTitle {
                name = cleanTitle(htmlTitle, for: .googleMaps)
            }
            
        case .appleMaps:
            if let htmlTitle = htmlTitle {
                name = cleanTitle(htmlTitle, for: .appleMaps)
            }
            
        default:
            // Generic handling
            if let htmlTitle = htmlTitle, !htmlTitle.isEmpty {
                name = cleanTitle(htmlTitle, for: .generic)
            } else if let text = text {
                let (caption, _) = extractCaptionAndURL(from: text)
                if let caption = caption {
                    name = cleanCaption(caption)
                    notes = caption
                }
            }
            
            if let htmlDescription = htmlDescription, notes == nil {
                notes = htmlDescription
            }
        }
        
        return (name, notes)
    }
    
    // MARK: - Caption/URL Extraction
    
    private static func extractCaptionAndURL(from text: String) -> (caption: String?, url: URL?) {
        logger.info("extractCaptionAndURL - input text: \(text)")
        
        // Find URL in text
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let range = NSRange(text.startIndex..., in: text)
        
        var url: URL? = nil
        var urlRange: Range<String.Index>? = nil
        
        if let match = detector?.firstMatch(in: text, options: [], range: range),
           let swiftRange = Range(match.range, in: text) {
            url = URL(string: String(text[swiftRange]))
            urlRange = swiftRange
            logger.info("extractCaptionAndURL - found URL: \(url?.absoluteString ?? "nil")")
        }
        
        // Extract caption - could be before OR after the URL
        var caption: String? = nil
        if let urlRange = urlRange {
            let beforeURL = String(text[..<urlRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            let afterURL = String(text[urlRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            
            logger.info("extractCaptionAndURL - before URL: '\(beforeURL)'")
            logger.info("extractCaptionAndURL - after URL: '\(afterURL)'")
            
            // Use whichever is longer/more meaningful
            if beforeURL.count > afterURL.count && !beforeURL.isEmpty {
                caption = beforeURL
            } else if !afterURL.isEmpty {
                caption = afterURL
            } else {
                caption = beforeURL.isEmpty ? nil : beforeURL
            }
        } else {
            caption = text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // Clean up caption - remove common prefixes/suffixes
        if var cap = caption {
            // Prefixes to remove
            let prefixesToRemove = [
                "Check out this video on TikTok",
                "Check out this TikTok",
                "Check this out",
                "Check out",
                "Look at this",
                "Watch this",
                "See this",
                "#tiktokmademebuyit",
                "#tiktok"
            ]
            for prefix in prefixesToRemove {
                if cap.lowercased().hasPrefix(prefix.lowercased()) {
                    cap = String(cap.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
            
            // Also check for these phrases anywhere and extract what comes after
            let phrasesToExtractAfter = [
                "you have to try",
                "you need to try", 
                "best spot for",
                "favorite spot",
                "my favorite",
                "new favorite",
                "discovered",
                "found this gem"
            ]
            for phrase in phrasesToExtractAfter {
                if let range = cap.lowercased().range(of: phrase) {
                    let afterPhrase = String(cap[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !afterPhrase.isEmpty && afterPhrase.count > 3 {
                        cap = afterPhrase
                        break
                    }
                }
            }
            
            caption = cap.isEmpty ? nil : cap
        }
        
        logger.info("extractCaptionAndURL - final caption: '\(caption ?? "nil")'")
        return (caption, url)
    }
    
    // MARK: - Place Name Extraction from Caption
    
    private static func extractPlaceNameFromCaption(_ caption: String) -> String? {
        logger.info("extractPlaceNameFromCaption - input: \(caption.prefix(150))")
        
        // PRIORITY 1: Look for 📍 pin emoji pattern - very common in TikTok/Instagram
        // Format: "📍place name" or "📍 place name - city" or "📍place name, city"
        // NOTE: This often contains addresses, so we need to distinguish business names from addresses
        let pinPatterns = [
            // 📍 followed by place name, then dash and location (e.g., "📍childish bakery - carrollton, tx")
            #"📍\s*([^-–—\n]+?)(?:\s*[-–—]\s*[A-Za-z\s,]+)?$"#,
            // 📍 followed by place name until end or newline
            #"📍\s*(.+?)(?:\n|$)"#,
            // 📍 at any position in caption (not just end)
            #"📍\s*([A-Za-z0-9][A-Za-z0-9'&\-\s]{2,50}?)(?:\s*[-–—]\s*[A-Za-z\s,]+|,|\n|$)"#,
        ]
        
        for pattern in pinPatterns {
            if let match = firstMatch(in: caption, pattern: pattern) {
                var cleaned = match.trimmingCharacters(in: .whitespacesAndNewlines)
                // Remove trailing location after dash if present (e.g., "childish bakery - carrollton, tx" -> "childish bakery")
                if let dashRange = cleaned.range(of: " - ") {
                    cleaned = String(cleaned[..<dashRange.lowerBound])
                }
                // Remove trailing comma and city/state (e.g., "childish bakery, tx" -> "childish bakery")
                if let commaRange = cleaned.range(of: ", ", options: .backwards) {
                    // Check if what's after comma looks like a city/state (short, likely 2-letter state or city name)
                    let afterComma = String(cleaned[commaRange.upperBound...]).lowercased().trimmingCharacters(in: .whitespaces)
                    // If it's 2-3 chars, likely a state code (TX, CA, NY, etc.)
                    // If it's longer but < 20 chars, likely a city name
                    // Check if it's all lowercase letters/spaces (city name pattern)
                    let isCityName = afterComma.allSatisfy { $0.isLowercase || $0.isWhitespace }
                    if afterComma.count <= 20 && (afterComma.count <= 3 || isCityName) {
                        cleaned = String(cleaned[..<commaRange.lowerBound])
                    }
                }
                cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
                
                // IMPORTANT: Skip if this looks like an address (starts with numbers)
                // Addresses like "4205 Buena Vista" should not be used as place names
                if cleaned.prefix(1).allSatisfy({ $0.isNumber }) {
                    logger.info("extractPlaceNameFromCaption - 📍 pin found address (skipping): \(cleaned)")
                    continue // Skip addresses, they're location hints, not business names
                }
                
                // Validate: reasonable length and not just common words
                if cleaned.count >= 2 && cleaned.count <= 60 && !isCommonWord(cleaned) {
                    logger.info("extractPlaceNameFromCaption - found via 📍 pin: \(cleaned)")
                    return cleaned
                }
            }
        }
        
        // PRIORITY 2: Common patterns for place mentions (case insensitive)
        // These patterns help catch place names even when there's no 📍 emoji
        let patterns = [
            // "at [Place Name]" - captures text after "at" or "@" (e.g., "at childish bakery")
            #"(?:^|\s)(?:at|@)\s+([A-Za-z][A-Za-z0-9'&\-\s]{2,40}?)(?:\s+in\s+|\s*[-–—]|\s*[!.,#]|\s*$)"#,
            // "called [Place Name]" (e.g., "a place called childish bakery")
            #"called\s+([A-Za-z][A-Za-z0-9'&\-\s]{2,40}?)(?:\s+in\s+|\s*[-–—]|\s*[!.,#]|\s*$)"#,
            // "to [Place Name]" (as in "went to", "go to", "heading to")
            #"(?:went to|going to|go to|heading to|visit|check out|tried|trying|stopped by|swung by)\s+([A-Za-z][A-Za-z0-9'&\-\s]{2,40}?)(?:\s+in\s+|\s*[-–—]|\s*[!.,#]|\s*$)"#,
            // "[Place Name] in [City]" pattern (e.g., "childish bakery in carrollton")
            #"([A-Z][A-Za-z0-9'&\-\s]{2,40}?)\s+in\s+[A-Z][a-z]+"#,
            // Hashtag that might be a place name: #PlaceName or #Place_Name (e.g., "#childishbakery")
            #"#([A-Z][A-Za-z0-9_]{2,30})"#,
            // "the [Place Name]" for places like "the Coffee Shop" or "the Cottage Grocery"
            #"(?:^|\s)the\s+([A-Z][A-Za-z0-9'&\-\s]{2,40}?)(?:\s+in\s+|\s*[-–—]|\s*[!.,#]|\s*$)"#,
            // Place name at the start of caption (common in TikTok, e.g., "Childish Bakery - best salt bread!")
            #"^([A-Z][A-Za-z0-9'&\-\s]{2,40}?)(?:\s*[-–—:!]|\s+is\s+|\s+has\s+|\s+-\s+)"#,
            // Place name followed by dash and description (e.g., "Childish Bakery - family owned...")
            #"([A-Z][A-Za-z0-9'&\-\s]{2,40}?)\s*[-–—]\s+[a-z]"#
        ]
        
        for pattern in patterns {
            if let match = firstMatch(in: caption, pattern: pattern) {
                var cleaned = match.trimmingCharacters(in: .whitespacesAndNewlines)
                // Remove trailing common words
                let trailingToRemove = [" is", " has", " was", " the", " a", " an"]
                for suffix in trailingToRemove {
                    if cleaned.lowercased().hasSuffix(suffix) {
                        cleaned = String(cleaned.dropLast(suffix.count))
                    }
                }
                cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Validate it's a reasonable place name
                if cleaned.count >= 3 && cleaned.count <= 50 && !isCommonWord(cleaned) && !isCommonPhrase(cleaned) {
                    logger.info("extractPlaceNameFromCaption - found via pattern: \(cleaned)")
                    return cleaned
                }
            }
        }
        
        // PRIORITY 3: Try to find capitalized phrases that might be business names
        let words = caption.components(separatedBy: CharacterSet.whitespaces.union(CharacterSet(charactersIn: ".,!?;:")))
        var consecutiveCapitalized: [String] = []
        
        for word in words {
            let cleaned = word.trimmingCharacters(in: .punctuationCharacters)
            // Check if word starts with uppercase (but isn't all caps like "THE")
            if let first = cleaned.first, 
               first.isUppercase && 
               cleaned.count > 1 &&
               !cleaned.allSatisfy({ $0.isUppercase }) {
                consecutiveCapitalized.append(cleaned)
            } else if !consecutiveCapitalized.isEmpty {
                // End of capitalized sequence
                if consecutiveCapitalized.count >= 2 {
                    let potentialName = consecutiveCapitalized.joined(separator: " ")
                    if !isCommonPhrase(potentialName) && potentialName.count >= 4 {
                        logger.info("extractPlaceNameFromCaption - found via capitalization: \(potentialName)")
                        return potentialName
                    }
                }
                consecutiveCapitalized = []
            }
        }
        
        // Check final sequence
        if consecutiveCapitalized.count >= 2 {
            let potentialName = consecutiveCapitalized.joined(separator: " ")
            if !isCommonPhrase(potentialName) && potentialName.count >= 4 {
                logger.info("extractPlaceNameFromCaption - found via final capitalization: \(potentialName)")
                return potentialName
            }
        }
        
        logger.info("extractPlaceNameFromCaption - no place name found via patterns, trying NLP...")
        
        // PRIORITY 4: Use Apple's Natural Language framework for Named Entity Recognition
        if let nlpResult = extractEntitiesUsingNLP(from: caption) {
            if let orgName = nlpResult.organizationName {
                logger.info("extractPlaceNameFromCaption - found via NLP (organization): \(orgName)")
                return orgName
            }
            if let placeName = nlpResult.placeName {
                logger.info("extractPlaceNameFromCaption - found via NLP (place): \(placeName)")
                return placeName
            }
        }
        
        logger.info("extractPlaceNameFromCaption - no place name found")
        return nil
    }
    
    // MARK: - Business Name Extraction (separate from address/location)
    
    /// Extracts business/restaurant names from captions, distinguishing them from addresses
    private static func extractBusinessName(from caption: String) -> String? {
        logger.info("extractBusinessName - input: \(caption.prefix(150))")
        
        // PRIORITY 1: Look for business names at the start of the caption
        // Common patterns: "Rose Café offers...", "Childish Bakery - best...", "The Cottage Grocery - family owned..."
        let startPatterns = [
            // Business name at start followed by "offers", "has", "is", etc.
            #"^([A-Z][A-Za-z0-9'&\-\s]{2,50}?)\s+(?:offers|has|is|was|serves|features|provides)"#,
            // Business name at start followed by dash and description
            #"^([A-Z][A-Za-z0-9'&\-\s]{2,50}?)\s*[-–—]\s+[a-z]"#,
            // "The [Business Name]" at start
            #"^The\s+([A-Z][A-Za-z0-9'&\-\s]{2,50}?)(?:\s+offers|\s+has|\s+is|\s*[-–—]|\s+in\s+)"#,
        ]
        
        for pattern in startPatterns {
            if let match = firstMatch(in: caption, pattern: pattern) {
                let cleaned = match.trimmingCharacters(in: .whitespacesAndNewlines)
                // Validate it's not an address (doesn't start with numbers)
                if !cleaned.prefix(1).allSatisfy({ $0.isNumber }) && 
                   cleaned.count >= 3 && 
                   cleaned.count <= 50 && 
                   !isCommonWord(cleaned) {
                    logger.info("extractBusinessName - found at start: \(cleaned)")
                    return cleaned
                }
            }
        }
        
        // PRIORITY 2: Use NLP to find organization names (businesses)
        if let nlpResult = extractEntitiesUsingNLP(from: caption) {
            // Filter out addresses (things that start with numbers) from organizations
            for org in nlpResult.allOrganizations {
                // Skip if it looks like an address (starts with number)
                if org.prefix(1).allSatisfy({ $0.isNumber }) {
                    continue
                }
                // Skip common delivery services
                if ["Uber Eats", "GrubHub", "Favor", "DoorDash", "Postmates"].contains(org) {
                    continue
                }
                // Prefer organization names that appear early in the caption
                if let range = caption.range(of: org, options: .caseInsensitive) {
                    let position = caption.distance(from: caption.startIndex, to: range.lowerBound)
                    // If it's in the first 100 characters, it's likely the main business
                    if position < 100 {
                        logger.info("extractBusinessName - found via NLP (early organization): \(org)")
                        return org
                    }
                }
            }
            // Fallback to first organization if none found early
            if let orgName = nlpResult.organizationName,
               !orgName.prefix(1).allSatisfy({ $0.isNumber }),
               !["Uber Eats", "GrubHub", "Favor", "DoorDash", "Postmates"].contains(orgName) {
                logger.info("extractBusinessName - found via NLP (organization): \(orgName)")
                return orgName
            }
        }
        
        // PRIORITY 3: Look for capitalized business names in the first part of caption
        // Split caption into sentences and check first sentence
        let firstSentence = caption.components(separatedBy: CharacterSet(charactersIn: ".!?")).first ?? caption
        let words = firstSentence.components(separatedBy: CharacterSet.whitespaces.union(CharacterSet(charactersIn: ",;:")))
        var consecutiveCapitalized: [String] = []
        
        for word in words.prefix(10) { // Only check first 10 words
            let cleaned = word.trimmingCharacters(in: .punctuationCharacters)
            if let first = cleaned.first,
               first.isUppercase &&
               cleaned.count > 1 &&
               !cleaned.allSatisfy({ $0.isUppercase }) &&
               !cleaned.prefix(1).allSatisfy({ $0.isNumber }) { // Not an address
                consecutiveCapitalized.append(cleaned)
            } else if !consecutiveCapitalized.isEmpty {
                if consecutiveCapitalized.count >= 2 {
                    let potentialName = consecutiveCapitalized.joined(separator: " ")
                    if !isCommonPhrase(potentialName) && potentialName.count >= 4 {
                        logger.info("extractBusinessName - found via capitalization: \(potentialName)")
                        return potentialName
                    }
                }
                consecutiveCapitalized = []
            }
        }
        
        logger.info("extractBusinessName - no business name found")
        return nil
    }
    
    // MARK: - NLP Entity Extraction
    
    struct NLPEntities {
        var organizationName: String?
        var placeName: String?
        var personName: String?
        var allOrganizations: [String] = []
        var allPlaces: [String] = []
    }
    
    private static func extractEntitiesUsingNLP(from text: String) -> NLPEntities? {
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text
        
        var entities = NLPEntities()
        let options: NLTagger.Options = [.omitPunctuation, .omitWhitespace, .joinNames]
        
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType, options: options) { tag, tokenRange in
            guard let tag = tag else { return true }
            
            let entity = String(text[tokenRange])
            
            switch tag {
            case .organizationName:
                logger.info("NLP found organization: \(entity)")
                entities.allOrganizations.append(entity)
                if entities.organizationName == nil {
                    entities.organizationName = entity
                }
            case .placeName:
                logger.info("NLP found place: \(entity)")
                entities.allPlaces.append(entity)
                if entities.placeName == nil {
                    entities.placeName = entity
                }
            case .personalName:
                logger.info("NLP found person: \(entity)")
                if entities.personName == nil {
                    entities.personName = entity
                }
            default:
                break
            }
            
            return true
        }
        
        // Return nil if no useful entities found
        if entities.organizationName == nil && entities.placeName == nil {
            return nil
        }
        
        return entities
    }
    
    // MARK: - General Place Name Extraction
    
    private static func extractPlaceNames(from text: String) -> [String] {
        var placeNames: [String] = []
        
        // Use NSDataDetector for addresses
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.address.rawValue) {
            let range = NSRange(text.startIndex..., in: text)
            let matches = detector.matches(in: text, options: [], range: range)
            
            for match in matches {
                if let swiftRange = Range(match.range, in: text) {
                    let address = String(text[swiftRange])
                    placeNames.append(address)
                }
            }
        }
        
        // Extract from caption patterns
        if let placeName = extractPlaceNameFromCaption(text) {
            if !placeNames.contains(placeName) {
                placeNames.insert(placeName, at: 0)
            }
        }
        
        return placeNames
    }
    
    // MARK: - Extract Location Hint from Caption
    // Extracts city/state info like "carrollton, tx" from "📍childish bakery - carrollton, tx"
    
    private static func extractLocationHint(from text: String) -> String? {
        // First try pattern matching for common formats
        let patterns = [
            // "📍name - city, state" or "📍name - city state"
            #"[-–—]\s*([A-Za-z\s]+,?\s*[A-Z]{2})\s*$"#,
            // "in city, state" at end
            #"in\s+([A-Za-z\s]+,\s*[A-Z]{2})\s*$"#,
            // Just "city, state" or "city, ST" pattern at end
            #",\s*([A-Za-z\s]+,\s*[A-Z]{2})\s*$"#,
        ]
        
        for pattern in patterns {
            if let match = firstMatch(in: text, pattern: pattern) {
                let cleaned = match.trimmingCharacters(in: .whitespacesAndNewlines)
                if cleaned.count >= 3 {
                    logger.info("extractLocationHint - found via pattern: \(cleaned)")
                    return cleaned
                }
            }
        }
        
        // Fall back to NLP to find place names (cities, etc.)
        if let nlpEntities = extractEntitiesUsingNLP(from: text) {
            // Use places that aren't the organization (likely the city)
            let places = nlpEntities.allPlaces.filter { place in
                // Filter out the organization name if it was also detected as a place
                if let org = nlpEntities.organizationName {
                    return !place.lowercased().contains(org.lowercased())
                }
                return true
            }
            
            if let cityHint = places.first {
                logger.info("extractLocationHint - found via NLP: \(cityHint)")
                return cityHint
            }
        }
        
        return nil
    }
    
    // MARK: - Category Detection
    
    private static func detectCategory(
        name: String,
        notes: String?,
        text: String,
        url: URL?
    ) -> (ContentType, EnrichedContent.CategoryConfidence, [String]) {
        
        let lowercaseText = text.lowercased()
        let lowercaseName = name.lowercased()
        var matchedKeywords: [String] = []
        
        // Check URL for category hints
        if let host = url?.host?.lowercased() {
            if host.contains("yelp") || host.contains("opentable") || host.contains("resy") {
                return (.restaurant, .high, ["restaurant booking site"])
            }
            if host.contains("alltrails") || host.contains("recreation.gov") {
                return (.activity, .high, ["outdoor activity site"])
            }
        }
        
        // Restaurant/Food keywords
        let restaurantKeywords = [
            "restaurant", "cafe", "coffee", "bakery", "bistro", "diner",
            "food", "eat", "brunch", "breakfast", "lunch", "dinner",
            "pizza", "sushi", "tacos", "burger", "ramen", "thai", "italian",
            "bar", "pub", "brewery", "winery", "cocktail",
            "delicious", "yummy", "tasty", "meal", "dish", "bread"
        ]
        
        for keyword in restaurantKeywords {
            if lowercaseText.contains(keyword) || lowercaseName.contains(keyword) {
                matchedKeywords.append(keyword)
            }
        }
        
        if matchedKeywords.count >= 2 {
            return (.restaurant, .high, matchedKeywords)
        } else if matchedKeywords.count == 1 {
            return (.restaurant, .medium, matchedKeywords)
        }
        
        // Shop keywords
        let shopKeywords = [
            "shop", "store", "boutique", "market", "mall",
            "buy", "shopping", "retail", "outlet",
            "bookstore", "clothing", "fashion", "jewelry"
        ]
        
        matchedKeywords = []
        for keyword in shopKeywords {
            if lowercaseText.contains(keyword) || lowercaseName.contains(keyword) {
                matchedKeywords.append(keyword)
            }
        }
        
        if matchedKeywords.count >= 2 {
            return (.shop, .high, matchedKeywords)
        } else if matchedKeywords.count == 1 {
            return (.shop, .medium, matchedKeywords)
        }
        
        // Activity keywords
        let activityKeywords = [
            "hike", "hiking", "trail", "park", "beach", "museum",
            "tour", "adventure", "explore", "visit", "attraction",
            "zoo", "aquarium", "garden", "theater", "theatre",
            "concert", "show", "event", "festival", "game",
            "spa", "gym", "fitness", "yoga", "climbing"
        ]
        
        matchedKeywords = []
        for keyword in activityKeywords {
            if lowercaseText.contains(keyword) || lowercaseName.contains(keyword) {
                matchedKeywords.append(keyword)
            }
        }
        
        if matchedKeywords.count >= 2 {
            return (.activity, .high, matchedKeywords)
        } else if matchedKeywords.count == 1 {
            return (.activity, .medium, matchedKeywords)
        }
        
        // Recipe keywords
        let recipeKeywords = [
            "recipe", "cook", "cooking", "bake", "baking",
            "ingredient", "homemade", "diy", "make this"
        ]
        
        matchedKeywords = []
        for keyword in recipeKeywords {
            if lowercaseText.contains(keyword) || lowercaseName.contains(keyword) {
                matchedKeywords.append(keyword)
            }
        }
        
        if matchedKeywords.count >= 1 {
            return (.recipe, .medium, matchedKeywords)
        }
        
        // Default to Place with low confidence
        return (.place, .low, [])
    }
    
    // MARK: - Place Search using MapKit
    
    private static func searchPlaces(
        query: String,
        near location: CLLocationCoordinate2D?,
        completion: @escaping ([ResolvedPlace]) -> Void
    ) {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        
        if let location = location {
            // Search near specific location
            request.region = MKCoordinateRegion(
                center: location,
                latitudinalMeters: 10000,
                longitudinalMeters: 10000
            )
        }
        
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            if let error = error {
                logger.error("Place search error: \(error.localizedDescription)")
                completion([])
                return
            }
            
            guard let response = response else {
                logger.warning("No place search results")
                completion([])
                return
            }
            
            let places = response.mapItems.prefix(5).map { item -> ResolvedPlace in
                let address = formatAddress(from: item)
                // Use location property (iOS 26+) or fallback to placemark
                let coordinate: CLLocationCoordinate2D
                if #available(iOS 26.0, *) {
                    // In iOS 26+, location is non-optional
                    coordinate = item.location.coordinate
                } else {
                    coordinate = item.placemark.coordinate
                }
                
                return ResolvedPlace(
                    name: item.name ?? query,
                    address: address,
                    latitude: coordinate.latitude,
                    longitude: coordinate.longitude,
                    category: item.pointOfInterestCategory?.rawValue,
                    phoneNumber: item.phoneNumber,
                    website: item.url
                )
            }
            
            logger.info("Found \(places.count) places for query: \(query)")
            completion(Array(places))
        }
    }
    
    // MARK: - Geocoding
    
    private static func geocodeAddress(_ address: String, completion: @escaping (ResolvedPlace?) -> Void) {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = address
        
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            if let error = error {
                logger.error("Geocoding error: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            guard let item = response?.mapItems.first else {
                completion(nil)
                return
            }
            
            let formattedAddress = formatAddress(from: item)
            // Use location property (iOS 26+) or fallback to placemark
            let coordinate: CLLocationCoordinate2D
            if #available(iOS 26.0, *) {
                // In iOS 26+, location is non-optional
                coordinate = item.location.coordinate
            } else {
                coordinate = item.placemark.coordinate
            }
            
            let place = ResolvedPlace(
                name: item.name ?? address,
                address: formattedAddress,
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                category: item.pointOfInterestCategory?.rawValue,
                phoneNumber: item.phoneNumber,
                website: item.url
            )
            
            completion(place)
        }
    }
    
    // MARK: - Helper Functions
    
    private static func formatAddress(from mapItem: MKMapItem) -> String {
        // Note: placemark is deprecated in iOS 26.0, but MKAddress has different structure
        // We continue using placemark as it's the most reliable way to get address components
        // TODO: Migrate to MKAddress when its API is better documented
        let placemark = mapItem.placemark
        var components: [String] = []
        
        if let subThoroughfare = placemark.subThoroughfare {
            components.append(subThoroughfare)
        }
        if let thoroughfare = placemark.thoroughfare {
            if components.isEmpty {
                components.append(thoroughfare)
            } else {
                components[0] += " " + thoroughfare
            }
        }
        if let locality = placemark.locality {
            components.append(locality)
        }
        if let administrativeArea = placemark.administrativeArea {
            components.append(administrativeArea)
        }
        if let postalCode = placemark.postalCode {
            if !components.isEmpty {
                components[components.count - 1] += " " + postalCode
            } else {
                components.append(postalCode)
            }
        }
        
        return components.isEmpty ? (mapItem.name ?? "Unknown") : components.joined(separator: ", ")
    }
    
    private static func isGenericTitle(_ title: String, for source: SourceType) -> Bool {
        let lowercased = title.lowercased()
        
        switch source {
        case .tiktok:
            return lowercased.contains("tiktok") && 
                   (lowercased.contains("make your day") || 
                    lowercased.contains("discover") ||
                    lowercased.count < 30)
        case .instagram:
            return lowercased.contains("instagram") &&
                   (lowercased.contains("photos and videos") ||
                    lowercased.contains("on instagram"))
        default:
            return false
        }
    }
    
    private static func cleanTitle(_ title: String, for source: SourceType) -> String {
        var cleaned = title
        
        // Remove common suffixes
        let suffixes = [
            " - Google Maps", " | Google Maps", " · Google Maps",
            " - Yelp", " | Yelp",
            " - Apple Maps",
            " on TikTok", " | TikTok",
            " • Instagram", " (@", " on Instagram"
        ]
        
        for suffix in suffixes {
            if let range = cleaned.range(of: suffix, options: .caseInsensitive) {
                cleaned = String(cleaned[..<range.lowerBound])
            }
        }
        
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private static func cleanCaption(_ caption: String) -> String {
        var cleaned = caption
        
        // Limit length
        if cleaned.count > 60 {
            // Find a good break point
            if let periodIndex = cleaned.prefix(60).lastIndex(of: ".") {
                cleaned = String(cleaned[...periodIndex])
            } else if let spaceIndex = cleaned.prefix(60).lastIndex(of: " ") {
                cleaned = String(cleaned[..<spaceIndex]) + "..."
            } else {
                cleaned = String(cleaned.prefix(57)) + "..."
            }
        }
        
        // Remove hashtags for the name
        cleaned = cleaned.replacingOccurrences(of: #"#\w+"#, with: "", options: .regularExpression)
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return cleaned
    }
    
    private static func firstMatch(in text: String, pattern: String) -> String? {
        let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex?.firstMatch(in: text, options: [], range: range) else { return nil }
        guard match.numberOfRanges > 1, let swiftRange = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[swiftRange])
    }
    
    private static func isCommonWord(_ word: String) -> Bool {
        let commonWords = Set([
            "the", "this", "that", "with", "from", "have", "been",
            "just", "best", "good", "great", "love", "like", "really",
            "amazing", "awesome", "beautiful", "perfect", "delicious",
            "first", "last", "next", "back", "here", "there",
            "new", "open", "now", "try", "tried", "going", "went"
        ])
        return commonWords.contains(word.lowercased())
    }
    
    private static func isCommonPhrase(_ phrase: String) -> Bool {
        let commonPhrases = Set([
            "New York", "Los Angeles", "San Francisco", "The Best",
            "My Favorite", "So Good", "Must Try", "Check Out",
            "This Place", "This Spot", "The Most", "One Of"
        ])
        return commonPhrases.contains(phrase)
    }
}
