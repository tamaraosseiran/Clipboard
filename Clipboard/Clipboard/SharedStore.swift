import Foundation

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
        
        init(name: String?, address: String?, latitude: Double?, longitude: Double?, photos: [URL], sourceURL: URL?, createdAt: Date) {
            self.name = name
            self.address = address
            self.latitude = latitude
            self.longitude = longitude
            self.photos = photos.map { $0.absoluteString }
            self.sourceURL = sourceURL?.absoluteString
            self.createdAt = createdAt
        }
        
        func toURLs() -> (photos: [URL], sourceURL: URL?) {
            let photoURLs = photos.compactMap { URL(string: $0) }
            let source = sourceURL.flatMap { URL(string: $0) }
            return (photoURLs, source)
        }
    }
    
    func savePending(draft: ParsedSpotDraft) throws {
        let spot = PendingSpot(
            name: draft.name,
            address: draft.address,
            latitude: draft.latitude,
            longitude: draft.longitude,
            photos: draft.photos,
            sourceURL: draft.sourceURL,
            createdAt: Date()
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(spot)
        
        guard let defaults = UserDefaults(suiteName: suite) else {
            throw NSError(domain: "SharedStore", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not access App Group UserDefaults"])
        }
        
        defaults.set(data, forKey: key)
        defaults.synchronize()
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

