//
//  ClipboardApp.swift
//  Clipboard
//
//  Created by Tamara Osseiran on 8/29/25.
//

import SwiftUI
import SwiftData

@main
struct ClipboardApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            ContentItem.self,
            Location.self,
            Category.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onContinueUserActivity("com.clipboard.addURL") { userActivity in
                    if let urlString = userActivity.userInfo?["url"] as? String {
                        // Handle the shared URL
                        NotificationCenter.default.post(
                            name: NSNotification.Name("AddSharedURL"),
                            object: nil,
                            userInfo: ["url": urlString]
                        )
                    }
                }
                .onOpenURL { url in
                    // Handle direct app sharing (when user shares TO the Clipboard app)
                    print("📱 Direct app sharing received URL: \(url.absoluteString)")
                    print("📱 URL scheme: \(url.scheme ?? "nil")")
                    print("📱 URL host: \(url.host ?? "nil")")
                    print("📱 URL path: \(url.path)")
                    
                    // Extract the actual URL from the clipboard:// scheme
                    let actualURL: String
                    if url.scheme == "clipboard" {
                        // If it's our custom scheme, extract the URL from the path or query
                        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                           let urlParam = components.queryItems?.first(where: { $0.name == "url" })?.value {
                            actualURL = urlParam
                        } else {
                            // Try to extract from path
                            let path = url.path
                            actualURL = path.hasPrefix("/") ? String(path.dropFirst()) : path
                        }
                    } else {
                        // If it's a direct URL, use it as is
                        actualURL = url.absoluteString
                    }
                    
                    print("📱 Extracted actual URL: \(actualURL)")
                    
                    NotificationCenter.default.post(
                        name: NSNotification.Name("AddSharedURL"),
                        object: nil,
                        userInfo: ["url": actualURL]
                    )
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
