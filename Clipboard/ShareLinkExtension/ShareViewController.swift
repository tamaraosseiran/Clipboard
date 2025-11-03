//
//  ShareViewController.swift
//  ShareLinkExtension
//
//  Created by Tamara Osseiran on 9/22/25.
//

import UIKit
import Social
import UniformTypeIdentifiers
import SwiftUI

// Local copy to avoid target membership issues
struct SharedContent: Codable {
    let url: String
    let title: String
    let description: String
    let contentType: String
    let timestamp: Date
}

final class ShareViewController: SLComposeServiceViewController {
    // Keep a strong reference so it isn't deallocated immediately
    private var previewHostingController: UIViewController?

    override func viewDidLoad() {
        super.viewDidLoad()
        print("📤 ShareLinkExtension: viewDidLoad called - extension is loading!")
        
        // Set a simple background color to make it visible
        view.backgroundColor = UIColor.systemBackground
        
        // Add a simple label to show the extension is working
        let label = UILabel()
        label.text = "Share to Spots"
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    override func isContentValid() -> Bool {
        // Content is considered valid; we handle extraction in didSelectPost
        print("📤 ShareLinkExtension: isContentValid called")
        return true
    }

    override func presentationAnimationDidFinish() {
        // Called when the share sheet finishes presenting. Start immediately.
        print("📤 ShareLinkExtension: presentationAnimationDidFinish - starting processing")
        startProcessing()
    }

    override func didSelectPost() {
        // Fallback if user taps Post; also start processing
        print("📤 ShareLinkExtension: didSelectPost called.")
        startProcessing()
    }

    private func startProcessing() {
        // Process items immediately without requiring Post
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else {
            print("❌ ShareLinkExtension: No input items found.")
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
            print("📦 ShareLinkExtension: Collected \(collectedURLs.count) URLs.")
            // Prefer first URL; fallback to empty string
            let first = collectedURLs.first?.absoluteString ?? ""
            let initial = SharePreviewData(
                urlString: first,
                title: self.guessTitle(from: first),
                description: "",
                address: "",
                contentType: self.guessCategory(from: first)
            )
            self.presentPreview(with: initial)
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

    // MARK: - Preview Presentation

    private func presentPreview(with data: SharePreviewData) {
        let hosting = UIHostingController(rootView: SharePreviewView(data: data) { updated in
            self.persistSharedContent(updated)
            self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        })

        // Push the SwiftUI view onto the extension's navigation stack
        DispatchQueue.main.async {
            self.previewHostingController = hosting
            self.pushConfigurationViewController(hosting)
        }
    }

    private func persistSharedContent(_ data: SharePreviewData) {
        guard let defaults = UserDefaults(suiteName: "group.com.tamaraosseiran.clipboard") else {
            print("❌ ShareLinkExtension: Failed to access App Group UserDefaults")
            return
        }
        let payload = SharedContent(url: data.urlString,
                                    title: data.title,
                                    description: data.description,
                                    contentType: data.contentType,
                                    timestamp: Date())
        var inbox = defaults.array(forKey: "SharedContent") as? [Data] ?? []
        if let encoded = try? JSONEncoder().encode(payload) {
            inbox.append(encoded)
            defaults.set(inbox, forKey: "SharedContent")
            defaults.synchronize()
            print("✅ ShareLinkExtension: Saved SharedContent. Inbox count: \(inbox.count)")
        }
    }

    private func guessTitle(from urlString: String) -> String {
        if urlString.contains("tiktok") { return "TikTok" }
        if urlString.contains("instagram") { return "Instagram" }
        if urlString.contains("yelp") { return "Yelp" }
        if urlString.contains("maps.google") { return "Google Maps" }
        return "Shared Content"
    }

    private func guessCategory(from urlString: String) -> String {
        if urlString.contains("yelp") || urlString.contains("maps") { return "restaurant" }
        return "other"
    }
}

