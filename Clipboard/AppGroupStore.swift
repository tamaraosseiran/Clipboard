import Foundation

// AppGroupStore for main app - only needs read/clear, not write
// The extension version (SharedStore) has savePending() with ParsedSpotDraft dependency
struct AppGroupStore {
    private let suite = "group.com.tamaraosseiran.clipboard"
    private let key = "pending_spot"
    
    struct PendingSpot: Codable {
        var name: String?
        var address: String?
        var latitude: Double?
        var longitude: Double?
        var photos: [String]  // Store as strings (URL paths)
        var sourceURL: String?  // Store as string
        var createdAt: Date
        
        func toURLs() -> (photos: [URL], sourceURL: URL?) {
            let photoURLs = photos.compactMap { URL(string: $0) }
            let source = sourceURL.flatMap { URL(string: $0) }
            return (photoURLs, source)
        }
    }
    
    func loadPending() -> PendingSpot? {
        guard let defaults = UserDefaults(suiteName: suite),
              let data = defaults.data(forKey: key) else {
            return nil
        }
        
        // Try to decode as JSON first
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            // Handle createdAt as timestamp (Double) or ISO8601 string
            var spot = PendingSpot(
                name: json["name"] as? String,
                address: json["address"] as? String,
                latitude: json["latitude"] as? Double,
                longitude: json["longitude"] as? Double,
                photos: [],
                sourceURL: json["sourceURL"] as? String,
                createdAt: Date()
            )
            
            // Parse createdAt
            if let timestamp = json["createdAt"] as? Double {
                spot.createdAt = Date(timeIntervalSince1970: timestamp)
            } else if let dateString = json["createdAt"] as? String {
                let formatter = ISO8601DateFormatter()
                spot.createdAt = formatter.date(from: dateString) ?? Date()
            }
            
            return spot
        }
        
        // Fallback to JSONDecoder
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(PendingSpot.self, from: data)
    }
    
    func clearPending() {
        UserDefaults(suiteName: suite)?.removeObject(forKey: key)
        UserDefaults(suiteName: suite)?.synchronize()
    }
}

