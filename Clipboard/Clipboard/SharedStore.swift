import Foundation

// Simplified SharedStore for main app - only needs to read, not write
struct SharedStore {
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
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(PendingSpot.self, from: data)
    }
    
    func clearPending() {
        UserDefaults(suiteName: suite)?.removeObject(forKey: key)
        UserDefaults(suiteName: suite)?.synchronize()
    }
}
