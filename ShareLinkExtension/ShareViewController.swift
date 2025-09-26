//
//  ShareViewController.swift
//  ShareLinkExtension
//
//  Created by Tamara Osseiran on 9/22/25.
//

import UIKit
import Social
import UniformTypeIdentifiers

final class ShareViewController: SLComposeServiceViewController {

    override func isContentValid() -> Bool {
        // Content is considered valid; we handle extraction in didSelectPost
        return true
    }

    override func didSelectPost() {
        // Called after the user taps Post
        print("📤 ShareLinkExtension: didSelectPost called.")
        
        // Process items immediately without complex UI
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else {
            print("❌ ShareLinkExtension: No input items found.")
            extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
            return
        }

        let providers = items.flatMap { $0.attachments ?? [] }
        if providers.isEmpty {
            print("❌ ShareLinkExtension: No attachments found.")
            extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
            return
        }

        var collectedURLs: [URL] = []
        let group = DispatchGroup()

        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                group.enter()
                provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { item, error in
                    defer { group.leave() }
                    if let url = item as? URL {
                        print("🔗 ShareLinkExtension: Found URL: \(url.absoluteString)")
                        collectedURLs.append(url)
                    } else if let str = item as? String, let url = URL(string: str) {
                        print("🔗 ShareLinkExtension: Found URL (from string): \(url.absoluteString)")
                        collectedURLs.append(url)
                    }
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.text.identifier) {
                group.enter()
                provider.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { item, error in
                    defer { group.leave() }
                    if let text = item as? String, let detected = Self.firstURL(in: text) {
                        print("📝 ShareLinkExtension: Found text with URL: \(detected.absoluteString)")
                        collectedURLs.append(detected)
                    }
                }
            }
        }

        group.notify(queue: .main) {
            print("📦 ShareLinkExtension: Collected \(collectedURLs.count) URLs. Saving to inbox.")
            self.saveToInbox(collectedURLs)
            self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        }
    }

    override func configurationItems() -> [Any]! {
        // No extra configuration items in the sheet
        return []
    }


    private func saveToInbox(_ urls: [URL]) {
        guard !urls.isEmpty else {
            print("⚠️ ShareLinkExtension: No URLs to save to inbox.")
            return
        }
        guard let defaults = UserDefaults(suiteName: "group.com.tamaraosseiran.clipboard") else {
            print("❌ ShareLinkExtension: Failed to get UserDefaults for App Group.")
            return
        }

        var inbox = defaults.array(forKey: "SharedURLInbox") as? [String] ?? []
        inbox.append(contentsOf: urls.map { $0.absoluteString })
        defaults.set(inbox, forKey: "SharedURLInbox")
        defaults.synchronize()
        print("✅ ShareLinkExtension: Saved \(urls.count) URLs to inbox. Current inbox count: \(inbox.count)")
    }

    private static func firstURL(in text: String) -> URL? {
        let types: NSTextCheckingResult.CheckingType = .link
        let detector = try? NSDataDetector(types: types.rawValue)
        let match = detector?.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text)).first
        if let range = match?.range, let swiftRange = Range(range, in: text) {
            return URL(string: String(text[swiftRange]))
        }
        return nil
    }
}

