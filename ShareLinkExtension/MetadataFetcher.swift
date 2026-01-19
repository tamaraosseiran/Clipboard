import Foundation
import OSLog
import UniformTypeIdentifiers

struct ParsedSpotDraft {
    var name: String?
    var address: String?
    var latitude: Double?
    var longitude: Double?
    var photos: [URL] = []
    var sourceURL: URL?
    
    static let empty = ParsedSpotDraft(name: nil, address: nil, latitude: nil, longitude: nil, photos: [], sourceURL: nil)
}

enum MetadataFetcher {
    
    // Store the caption from oEmbed for use by ContentEnricher
    static var lastFetchedCaption: String?
    
    static func buildDraft(from candidate: SharedCandidate, logger: Logger, completion: @escaping (ParsedSpotDraft) -> Void) {
        var draft = ParsedSpotDraft.empty
        draft.sourceURL = candidate.sourceURL
        lastFetchedCaption = nil
        
        // Add image and movie files to photos array
        if let img = candidate.imageFileURL {
            draft.photos.append(img)
        }
        if let mov = candidate.movieFileURL {
            draft.photos.append(mov)
        }
        
        guard let url = candidate.sourceURL else {
            // No URL: we can only prefill with what we have; name stays blank.
            logger.info("No source URL, returning draft with raw data only")
            completion(draft)
            return
        }
        
        // Check if this is a TikTok URL - use oEmbed API first
        if url.host?.contains("tiktok.com") == true {
            logger.info("Detected TikTok URL, fetching via oEmbed API")
            fetchTikTokOEmbed(url: url, logger: logger) { oembedResult in
                if let result = oembedResult {
                    draft.name = result.title
                    lastFetchedCaption = result.title // Store the caption
                    logger.info("TikTok oEmbed result - title: \(result.title ?? "nil")")
                }
                // Continue with standard metadata fetch for additional info
                self.fetchStandardMetadata(url: url, draft: draft, candidate: candidate, logger: logger, completion: completion)
            }
            return
        }
        
        // Check if this is an Instagram URL - use oEmbed API
        if url.host?.contains("instagram.com") == true {
            logger.info("Detected Instagram URL, fetching via oEmbed API")
            fetchInstagramOEmbed(url: url, logger: logger) { oembedResult in
                if let result = oembedResult {
                    draft.name = result.title
                    lastFetchedCaption = result.title
                    logger.info("Instagram oEmbed result - title: \(result.title ?? "nil")")
                }
                self.fetchStandardMetadata(url: url, draft: draft, candidate: candidate, logger: logger, completion: completion)
            }
            return
        }
        
        // For non-social media URLs, go straight to standard fetch
        fetchStandardMetadata(url: url, draft: draft, candidate: candidate, logger: logger, completion: completion)
    }
    
    // MARK: - TikTok oEmbed API
    private static func fetchTikTokOEmbed(url: URL, logger: Logger, completion: @escaping ((title: String?, authorName: String?)?) -> Void) {
        // TikTok oEmbed endpoint
        let oembedURL = "https://www.tiktok.com/oembed?url=\(url.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        
        guard let requestURL = URL(string: oembedURL) else {
            logger.warning("Failed to create TikTok oEmbed URL")
            completion(nil)
            return
        }
        
        var request = URLRequest(url: requestURL)
        request.timeoutInterval = 10
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                logger.warning("TikTok oEmbed error: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            guard let data = data else {
                logger.warning("TikTok oEmbed returned no data")
                completion(nil)
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    let title = json["title"] as? String
                    let authorName = json["author_name"] as? String
                    logger.info("TikTok oEmbed parsed - title: \(title ?? "nil"), author: \(authorName ?? "nil")")
                    completion((title: title, authorName: authorName))
                } else {
                    logger.warning("TikTok oEmbed JSON parsing failed")
                    completion(nil)
                }
            } catch {
                logger.warning("TikTok oEmbed JSON error: \(error.localizedDescription)")
                completion(nil)
            }
        }
        task.resume()
    }
    
    // MARK: - Instagram oEmbed API
    private static func fetchInstagramOEmbed(url: URL, logger: Logger, completion: @escaping ((title: String?, authorName: String?)?) -> Void) {
        // Instagram oEmbed endpoint (requires app token in production, but basic info works without)
        let oembedURL = "https://api.instagram.com/oembed?url=\(url.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        
        guard let requestURL = URL(string: oembedURL) else {
            completion(nil)
            return
        }
        
        var request = URLRequest(url: requestURL)
        request.timeoutInterval = 10
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                completion(nil)
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    let title = json["title"] as? String
                    let authorName = json["author_name"] as? String
                    completion((title: title, authorName: authorName))
                } else {
                    completion(nil)
                }
            } catch {
                completion(nil)
            }
        }
        task.resume()
    }
    
    // MARK: - Standard Metadata Fetch (moved from buildDraft)
    private static func fetchStandardMetadata(url: URL, draft: ParsedSpotDraft, candidate: SharedCandidate, logger: Logger, completion: @escaping (ParsedSpotDraft) -> Void) {
        var draft = draft
        
        // Fetch HTML and parse minimal OpenGraph title & image.
        logger.info("Fetching metadata for URL: \(url.absoluteString)")
        DispatchQueue.global(qos: .userInitiated).async {
            var title: String? = nil
            var ogImage: URL? = nil
            
            // First, resolve redirects (especially for Google Share links)
            let resolvedURL = self.resolveRedirect(url: url, logger: logger) ?? url
            logger.info("Resolved URL: \(resolvedURL.absoluteString)")
            
            // Attempt to fetch HTML content using URLSession for better control
            let semaphore = DispatchSemaphore(value: 0)
            var html: String? = nil
            var fetchError: Error? = nil
            
            var request = URLRequest(url: resolvedURL)
            request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
            request.timeoutInterval = 10
            
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    fetchError = error
                    semaphore.signal()
                    return
                }
                if let data = data, let string = String(data: data, encoding: .utf8) {
                    html = string
                }
                semaphore.signal()
            }
            task.resume()
            
            // Wait for fetch with timeout (10 seconds)
            if semaphore.wait(timeout: .now() + 10) == .timedOut {
                logger.warning("Metadata fetch timed out")
                task.cancel()
            }
            
            if let html = html {
                // First, try to extract structured data (JSON-LD) - Google Maps uses this
                if let structuredData = extractStructuredData(from: html, logger: logger) {
                    title = structuredData.name ?? title
                    draft.address = structuredData.address ?? draft.address
                    if let lat = structuredData.latitude, let lon = structuredData.longitude {
                        draft.latitude = lat
                        draft.longitude = lon
                    }
                    if let img = structuredData.image {
                        ogImage = img
                    }
                    logger.info("Extracted from structured data: \(structuredData.name ?? "nil")")
                }
                
                // Try to extract OpenGraph title (multiple patterns)
                if title == nil {
                    title = firstMatch(in: html, pattern: #"<meta[^>]*property=["']og:title["'][^>]*content=["'](.*?)["']"#)
                             ?? firstMatch(in: html, pattern: #"<meta[^>]*name=["']twitter:title["'][^>]*content=["'](.*?)["']"#)
                             ?? firstMatch(in: html, pattern: #"<meta[^>]*name=["']title["'][^>]*content=["'](.*?)["']"#)
                             ?? firstMatch(in: html, pattern: #"<h1[^>]*>(.*?)</h1>"#)  // Try H1 tag
                             ?? firstMatch(in: html, pattern: #"<title[^>]*>(.*?)</title>"#)
                }
                
                // If still no title, try to extract from common patterns in restaurant/place websites
                if title == nil || title?.lowercased().contains("google") == true {
                    // Try to find restaurant/place name in common HTML patterns
                    let patterns = [
                        #"<h1[^>]*class=["'][^"']*name["'][^>]*>(.*?)</h1>"#,
                        #"<span[^>]*class=["'][^"']*name["'][^>]*>(.*?)</span>"#,
                        #"data-name=["'](.*?)["']"#,
                        #"itemprop=["']name["'][^>]*>(.*?)</"#
                    ]
                    
                    for pattern in patterns {
                        if let found = firstMatch(in: html, pattern: pattern), !found.isEmpty {
                            title = found
                            logger.info("Extracted title from pattern: \(found)")
                            break
                        }
                    }
                }
                
                // Clean up title - remove common suffixes and clean HTML entities
                if let t = title {
                    title = t
                        .replacingOccurrences(of: "&amp;", with: "&")
                        .replacingOccurrences(of: "&lt;", with: "<")
                        .replacingOccurrences(of: "&gt;", with: ">")
                        .replacingOccurrences(of: "&quot;", with: "\"")
                        .replacingOccurrences(of: "&#39;", with: "'")
                        .replacingOccurrences(of: " - Google Maps", with: "")
                        .replacingOccurrences(of: " | Google Maps", with: "")
                        .replacingOccurrences(of: " - Google Search", with: "")
                        .replacingOccurrences(of: " · Google Maps", with: "")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                }
                
                // Try to extract OpenGraph image
                if ogImage == nil {
                    if let imgStr = firstMatch(in: html, pattern: #"<meta[^>]*property=["']og:image["'][^>]*content=["'](.*?)["']"#) {
                        // Handle relative URLs
                        if imgStr.hasPrefix("http://") || imgStr.hasPrefix("https://") {
                            ogImage = URL(string: imgStr)
                        } else if imgStr.hasPrefix("//") {
                            ogImage = URL(string: "https:\(imgStr)")
                        } else if imgStr.hasPrefix("/") {
                            ogImage = URL(string: "\(resolvedURL.scheme ?? "https")://\(resolvedURL.host ?? "")\(imgStr)")
                        } else {
                            // Relative path
                            let baseURL = resolvedURL.deletingLastPathComponent()
                            ogImage = URL(string: imgStr, relativeTo: baseURL)?.absoluteURL
                        }
                    }
                }
                
                // Try to extract address from page if not already found
                if draft.address == nil {
                    draft.address = extractAddressFromHTML(html, logger: logger)
                }
                
                logger.info("Extracted title: \(title ?? "nil"), address: \(draft.address ?? "nil"), ogImage: \(ogImage?.absoluteString ?? "nil")")
            } else if let error = fetchError {
                logger.error("Failed to fetch HTML: \(error.localizedDescription)")
                // Fallback: try to extract from resolved URL path
                title = extractTitleFromURL(resolvedURL)
            } else {
                logger.warning("No HTML content received")
                // Fallback: try to extract from resolved URL path
                title = extractTitleFromURL(resolvedURL)
            }
            
            draft.name = title
            if let og = ogImage {
                draft.photos.append(og)
            }
            
            // Try to infer address from URL or text if available
            if let text = candidate.rawText {
                draft.address = extractAddressFromText(text, logger: logger)
            }
            
            // TODO: Geocoding step (stub): if we can extract address from page, do it here.
            // For now, we'll leave address as nil if not found in text
            
            completion(draft)
        }
    }
    
    private static func firstMatch(in text: String, pattern: String) -> String? {
        let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators, .caseInsensitive])
        let range = NSRange(text.startIndex..., in: text)
        guard let m = regex?.firstMatch(in: text, options: [], range: range) else { return nil }
        guard m.numberOfRanges > 1, let r = Range(m.range(at: 1), in: text) else { return nil }
        return String(text[r]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private static func extractAddressFromText(_ text: String, logger: Logger) -> String? {
        // Use NSDataDetector to find addresses in text
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.address.rawValue)
        let matches = detector?.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text))
        
        if let firstMatch = matches?.first, let range = Range(firstMatch.range, in: text) {
            let address = String(text[range])
            logger.info("Extracted address from text: \(address)")
            return address
        }
        return nil
    }
    
    // MARK: - Resolve Redirect URLs
    private static func resolveRedirect(url: URL, logger: Logger) -> URL? {
        // Handle Google Share links and other redirects
        guard url.host?.contains("share.google") == true || url.host?.contains("goo.gl") == true else {
            return url
        }
        
        let semaphore = DispatchSemaphore(value: 0)
        var resolvedURL: URL? = url
        
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD" // Use HEAD to avoid downloading full content
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 5
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let httpResponse = response as? HTTPURLResponse,
               let location = httpResponse.value(forHTTPHeaderField: "Location"),
               let newURL = URL(string: location) {
                resolvedURL = newURL
                logger.info("Resolved redirect: \(url.absoluteString) -> \(newURL.absoluteString)")
            } else if let httpResponse = response as? HTTPURLResponse {
                // If no Location header, use the final URL from the response
                resolvedURL = httpResponse.url ?? url
                logger.info("No redirect found, using response URL: \(resolvedURL?.absoluteString ?? "nil")")
            }
            semaphore.signal()
        }
        task.resume()
        
        // Wait for redirect resolution with timeout
        if semaphore.wait(timeout: .now() + 5) == .timedOut {
            logger.warning("Redirect resolution timed out")
            task.cancel()
        }
        
        return resolvedURL
    }
    
    // MARK: - Extract Title from URL
    private static func extractTitleFromURL(_ url: URL) -> String? {
        // Try to extract meaningful title from URL path
        let path = url.path
        let pathComponents = path.components(separatedBy: "/").filter { !$0.isEmpty }
        
        // For Google Maps URLs, try to extract place name
        if url.host?.contains("maps.google") == true || url.host?.contains("google.com") == true {
            if let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems {
                // Check for q parameter (query/place name)
                if let placeName = queryItems.first(where: { $0.name == "q" })?.value {
                    return placeName.removingPercentEncoding
                }
            }
        }
        
        // Use last path component if it's meaningful
        if let lastComponent = pathComponents.last,
           lastComponent.count > 2,
           !lastComponent.contains(".") {
            return lastComponent.replacingOccurrences(of: "-", with: " ").replacingOccurrences(of: "_", with: " ").capitalized
        }
        
        // Fallback to host
        return url.host?.replacingOccurrences(of: "www.", with: "").capitalized
    }
    
    // MARK: - Extract Structured Data (JSON-LD)
    private static func extractStructuredData(from html: String, logger: Logger) -> StructuredData? {
        // Find all JSON-LD script tags
        let pattern = #"<script[^>]*type=["']application/ld\+json["'][^>]*>(.*?)</script>"#
        let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators, .caseInsensitive])
        let range = NSRange(html.startIndex..., in: html)
        
        guard let matches = regex?.matches(in: html, options: [], range: range) else {
            return nil
        }
        
        for match in matches {
            guard match.numberOfRanges > 1,
                  let jsonRange = Range(match.range(at: 1), in: html) else {
                continue
            }
            
            let jsonString = String(html[jsonRange])
            
            // Try to parse as JSON
            guard let jsonData = jsonString.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                continue
            }
            
            // Check if it's a LocalBusiness or Restaurant (Google Maps uses these)
            if let type = json["@type"] as? String,
               (type.contains("LocalBusiness") || type.contains("Restaurant") || type.contains("FoodEstablishment")) {
                
                let name: String? = json["name"] as? String
                var address: String? = nil
                var latitude: Double? = nil
                var longitude: Double? = nil
                var image: URL? = nil
                
                // Extract address from address object
                if let addressObj = json["address"] as? [String: Any] {
                    var addressParts: [String] = []
                    if let street = addressObj["streetAddress"] as? String {
                        addressParts.append(street)
                    }
                    if let city = addressObj["addressLocality"] as? String {
                        addressParts.append(city)
                    }
                    if let state = addressObj["addressRegion"] as? String {
                        addressParts.append(state)
                    }
                    if let zip = addressObj["postalCode"] as? String {
                        addressParts.append(zip)
                    }
                    if !addressParts.isEmpty {
                        address = addressParts.joined(separator: ", ")
                    }
                }
                
                // Extract coordinates
                if let geo = json["geo"] as? [String: Any] {
                    if let lat = geo["latitude"] as? Double {
                        latitude = lat
                    } else if let latStr = geo["latitude"] as? String {
                        latitude = Double(latStr)
                    }
                    if let lon = geo["longitude"] as? Double {
                        longitude = lon
                    } else if let lonStr = geo["longitude"] as? String {
                        longitude = Double(lonStr)
                    }
                }
                
                // Extract image
                if let imgStr = json["image"] as? String {
                    image = URL(string: imgStr)
                } else if let imgObj = json["image"] as? [String: Any],
                          let imgStr = imgObj["url"] as? String {
                    image = URL(string: imgStr)
                }
                
                logger.info("Found structured data: \(name ?? "nil") at \(address ?? "nil")")
                return StructuredData(name: name, address: address, latitude: latitude, longitude: longitude, image: image)
            }
        }
        
        return nil
    }
    
    // MARK: - Extract Address from HTML
    private static func extractAddressFromHTML(_ html: String, logger: Logger) -> String? {
        // Try multiple patterns for address extraction
        // Pattern 1: itemprop="address" or similar
        if let address = firstMatch(in: html, pattern: #"itemprop=["']address["'][^>]*>(.*?)</"#) {
            return cleanHTML(address)
        }
        
        // Pattern 2: Common address patterns in Google Maps
        if let address = firstMatch(in: html, pattern: #"data-value=["']([^"']*,\s*[A-Z]{2}\s*\d{5})["']"#) {
            return address
        }
        
        // Pattern 3: Look for address-like patterns
        let addressPattern = #"\d+\s+[A-Za-z\s]+(?:Street|St|Avenue|Ave|Road|Rd|Boulevard|Blvd|Drive|Dr|Lane|Ln|Way|Court|Ct|Place|Pl)[^<]*"#
        if let address = firstMatch(in: html, pattern: addressPattern) {
            return address.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        return nil
    }
    
    private static func cleanHTML(_ text: String) -> String {
        return text
            .replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Structured Data Model
    private struct StructuredData {
        let name: String?
        let address: String?
        let latitude: Double?
        let longitude: Double?
        let image: URL?
    }
}

