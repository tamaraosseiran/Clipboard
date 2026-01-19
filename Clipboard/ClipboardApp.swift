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
        
        // First, try to create a persistent store
        do {
            let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            print("❌ Could not create persistent ModelContainer: \(error)")
            print("🔄 Attempting to reset database...")
            
            // Try to delete the existing store files
            let fileManager = FileManager.default
            if let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
                // Delete all possible SwiftData/CoreData files
                let filesToDelete = [
                    "default.store",
                    "default.store-shm",
                    "default.store-wal",
                    "Model.sqlite",
                    "Model.sqlite-shm",
                    "Model.sqlite-wal"
                ]
                for file in filesToDelete {
                    let fileURL = appSupport.appendingPathComponent(file)
                    try? fileManager.removeItem(at: fileURL)
                }
            }
            
            // Try again with persistent store after cleanup
            do {
                let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
                return try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                print("❌ Still failed after reset: \(error)")
                print("⚠️ Falling back to in-memory store (data will not persist)")
                
                // Last resort: use in-memory store so the app at least launches
                do {
                    let inMemoryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                    return try ModelContainer(for: schema, configurations: [inMemoryConfig])
                } catch {
                    // This should never happen, but if it does, there's a fundamental issue with the models
                    fatalError("Could not create even an in-memory ModelContainer: \(error)")
                }
            }
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
                    print("📱 [ClipboardApp] onOpenURL called: \(url.absoluteString)")
                    
                    // Handle spots://import from share extension
                    if url.scheme == "spots" && url.host == "import" {
                        print("✅ [ClipboardApp] Received spots://import - checking for shared content")
                        // Trigger content check via notification
                        NotificationCenter.default.post(
                            name: NSNotification.Name("CheckForSharedContent"),
                            object: nil
                        )
                        return
                    }
                    
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
