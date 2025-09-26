import Foundation
import AppIntents
import SwiftUI
import SwiftData

// MARK: - App Actions for TikTok Video Processing

@available(iOS 16.0, *)
struct SaveToSpotsIntent: AppIntent {
    static var title: LocalizedStringResource = "Save to Spots"
    static var description = IntentDescription("Save content to Spots - extract location, category, and details from any shared content")
    
    @Parameter(title: "Content URL")
    var contentURL: String?
    
    @Parameter(title: "Content Title")
    var contentTitle: String?
    
    @Parameter(title: "Content Description")
    var contentDescription: String?
    
    @Parameter(title: "Content Type")
    var contentType: String?
    
    func perform() async throws -> some IntentResult {
        // This will be called when the user selects "Save to Spots" from the share sheet
        print("📱 SaveToSpotsIntent: Processing content")
        print("📱 Content URL: \(contentURL ?? "nil")")
        print("📱 Content Title: \(contentTitle ?? "nil")")
        print("📱 Content Description: \(contentDescription ?? "nil")")
        print("📱 Content Type: \(contentType ?? "nil")")
        
        // Store the shared content for the main app to process
        if let url = contentURL {
            let sharedContent = SharedContent(
                url: url,
                title: contentTitle ?? "Shared Content",
                description: contentDescription ?? "",
                contentType: contentType ?? "unknown",
                timestamp: Date()
            )
            
            // Save to UserDefaults for the main app to pick up
            if let defaults = UserDefaults(suiteName: "group.com.tamaraosseiran.clipboard") {
                var sharedContent = defaults.array(forKey: "SharedContent") as? [Data] ?? []
                if let data = try? JSONEncoder().encode(sharedContent) {
                    sharedContent.append(data)
                    defaults.set(sharedContent, forKey: "SharedContent")
                    defaults.synchronize()
                    print("✅ Saved shared content to App Group")
                }
            }
        }
        
        return .result()
    }
}

// MARK: - Shared Content Model

struct SharedContent: Codable {
    let url: String
    let title: String
    let description: String
    let contentType: String
    let timestamp: Date
}

// MARK: - App Actions Configuration
// Note: AppIntentsProvider is not needed in iOS 18+
// The system automatically discovers App Intents
