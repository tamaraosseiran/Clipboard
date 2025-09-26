import Foundation
import AppIntents
import SwiftUI
import SwiftData

// MARK: - App Actions for TikTok Video Processing

@available(iOS 16.0, *)
struct ProcessTikTokVideoIntent: AppIntent {
    static var title: LocalizedStringResource = "Save to Spots"
    static var description = IntentDescription("Process TikTok video and extract location, category, and details")
    
    @Parameter(title: "Video URL")
    var videoURL: String?
    
    @Parameter(title: "Video Title")
    var videoTitle: String?
    
    @Parameter(title: "Video Description")
    var videoDescription: String?
    
    func perform() async throws -> some IntentResult {
        // This will be called when the user selects "Save to Spots" from the share sheet
        print("🎬 ProcessTikTokVideoIntent: Processing video")
        print("🎬 Video URL: \(videoURL ?? "nil")")
        print("🎬 Video Title: \(videoTitle ?? "nil")")
        print("🎬 Video Description: \(videoDescription ?? "nil")")
        
        // Store the shared content for the main app to process
        if let url = videoURL {
            let sharedContent = SharedVideoContent(
                url: url,
                title: videoTitle ?? "TikTok Video",
                description: videoDescription ?? "",
                timestamp: Date()
            )
            
            // Save to UserDefaults for the main app to pick up
            if let defaults = UserDefaults(suiteName: "group.com.tamaraosseiran.clipboard") {
                var sharedVideos = defaults.array(forKey: "SharedVideos") as? [Data] ?? []
                if let data = try? JSONEncoder().encode(sharedContent) {
                    sharedVideos.append(data)
                    defaults.set(sharedVideos, forKey: "SharedVideos")
                    defaults.synchronize()
                    print("✅ Saved shared video content to App Group")
                }
            }
        }
        
        return .result()
    }
}

// MARK: - Shared Video Content Model

struct SharedVideoContent: Codable {
    let url: String
    let title: String
    let description: String
    let timestamp: Date
}

// MARK: - App Actions Configuration
// Note: AppIntentsProvider is not needed in iOS 18+
// The system automatically discovers App Intents
