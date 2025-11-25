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
        
        // Try new simplified format first (JSON dictionary)
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            print("✅ [AppGroupStore] Found new format (JSON dictionary)")
            let name = json["name"] as? String
            let address = json["address"] as? String
            let sourceURL = json["sourceURL"] as? String
            let timestamp = json["createdAt"] as? TimeInterval ?? Date().timeIntervalSince1970
            let _ = json["contentType"] as? String // Reserved for future use
            let _ = json["notes"] as? String // Reserved for future use
            
            print("📋 [AppGroupStore] Parsed: name=\(name ?? "nil"), address=\(address ?? "nil"), url=\(sourceURL ?? "nil")")
            
            return PendingSpot(
                name: name,
                address: address,
                latitude: nil,
                longitude: nil,
                photos: [],
                sourceURL: sourceURL,
                createdAt: Date(timeIntervalSince1970: timestamp)
            )
        }
        
        // Try old Codable format
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let spot = try? decoder.decode(PendingSpot.self, from: data) {
            print("✅ [AppGroupStore] Found old format (Codable)")
            return spot
        }
        
        print("❌ [AppGroupStore] Could not decode pending spot data")
        return nil
    }
    
    func clearPending() {
        UserDefaults(suiteName: suite)?.removeObject(forKey: key)
        UserDefaults(suiteName: suite)?.synchronize()
    }
}

