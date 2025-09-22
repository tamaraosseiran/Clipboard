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
        handleIncomingItems { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        }
    }

    override func configurationItems() -> [Any]! {
        // No extra configuration items in the sheet
        return []
    }

    private func handleIncomingItems(completion: @escaping () -> Void) {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else {
            completion()
            return
        }

        let providers = items.flatMap { $0.attachments ?? [] }
        if providers.isEmpty {
            completion()
            return
        }

        let group = DispatchGroup()
        var collectedURLs: [URL] = []

        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                group.enter()
                provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { item, _ in
                    defer { group.leave() }
                    if let url = item as? URL {
                        collectedURLs.append(url)
                    } else if let str = item as? String, let url = URL(string: str) {
                        collectedURLs.append(url)
                    }
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.text.identifier) {
                group.enter()
                provider.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { item, _ in
                    defer { group.leave() }
                    if let text = item as? String, let detected = Self.firstURL(in: text) {
                        collectedURLs.append(detected)
                    }
                }
            }
        }

        group.notify(queue: .main) {
            self.saveToInbox(collectedURLs)
            completion()
        }
    }

    private func saveToInbox(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        guard let defaults = UserDefaults(suiteName: AppGroup.identifier) else { return }

        var inbox = defaults.array(forKey: SharedKeys.inbox) as? [String] ?? []
        inbox.append(contentsOf: urls.map { $0.absoluteString })
        defaults.set(inbox, forKey: SharedKeys.inbox)
        defaults.synchronize()
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
