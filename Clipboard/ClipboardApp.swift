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
        }
        .modelContainer(sharedModelContainer)
    }
}
