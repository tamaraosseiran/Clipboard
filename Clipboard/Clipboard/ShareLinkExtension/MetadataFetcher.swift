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
    static func buildDraft(from candidate: SharedCandidate, logger: Logger, completion: @escaping (ParsedSpotDraft) -> Void) {
        var draft = ParsedSpotDraft.empty
        draft.sourceURL = candidate.sourceURL
        
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
        
        // Fetch HTML and parse minimal OpenGraph title & image.
        logger.info("Fetching metadata for URL: \(url.absoluteString)")
        DispatchQueue.global(qos: .userInitiated).async {
            var title: String? = nil
            var ogImage: URL? = nil
            
            // Attempt to fetch HTML content using URLSession for better control
            let semaphore = DispatchSemaphore(value: 0)
            var html: String? = nil
            var fetchError: Error? = nil
            
            let task = URLSession.shared.dataTask(with: url) { data, response, error in
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
            
            // Wait for fetch with timeout (5 seconds)
            if semaphore.wait(timeout: .now() + 5) == .timedOut {
                logger.warning("Metadata fetch timed out")
                task.cancel()
            }
            
            if let html = html {
                
                // Try to extract OpenGraph title
                title = firstMatch(in: html, pattern: #"<meta[^>]*property=["']og:title["'][^>]*content=["'](.*?)["']"#)
                         ?? firstMatch(in: html, pattern: #"<title[^>]*>(.*?)</title>"#)
                
                // Try to extract OpenGraph image
                if let imgStr = firstMatch(in: html, pattern: #"<meta[^>]*property=["']og:image["'][^>]*content=["'](.*?)["']"#) {
                    // Handle relative URLs
                    if imgStr.hasPrefix("http://") || imgStr.hasPrefix("https://") {
                        ogImage = URL(string: imgStr)
                    } else if imgStr.hasPrefix("//") {
                        ogImage = URL(string: "https:\(imgStr)")
                    } else if imgStr.hasPrefix("/") {
                        ogImage = URL(string: "\(url.scheme ?? "https")://\(url.host ?? "")\(imgStr)")
                    } else {
                        // Relative path
                        let baseURL = url.deletingLastPathComponent()
                        ogImage = URL(string: imgStr, relativeTo: baseURL)?.absoluteURL
                    }
                }
                
                logger.info("Extracted title: \(title ?? "nil"), ogImage: \(ogImage?.absoluteString ?? "nil")")
            } else if let error = fetchError {
                logger.error("Failed to fetch HTML: \(error.localizedDescription)")
                // Fallback: try to use URL host as title
                title = url.host ?? url.absoluteString
            } else {
                logger.warning("No HTML content received")
                // Fallback: try to use URL host as title
                title = url.host ?? url.absoluteString
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
}

