//
//  ShareViewController.swift
//  ShareExtension
//
//  Created by Tamara Osseiran on 8/29/25.
//

import UIKit
import Social
import MobileCoreServices

class ShareViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Get the shared URL
        if let extensionContext = extensionContext {
            let attachments = extensionContext.inputItems.compactMap { $0 as? NSExtensionItem }.flatMap { $0.attachments ?? [] }
            
            for attachment in attachments {
                // Handle URLs
                if attachment.hasItemConformingToTypeIdentifier(kUTTypeURL as String) {
                    attachment.loadItem(forTypeIdentifier: kUTTypeURL as String, options: nil) { [weak self] (item, error) in
                        DispatchQueue.main.async {
                            if let url = item as? URL {
                                self?.handleSharedURL(url)
                            }
                        }
                    }
                }
                // Handle text that might contain URLs
                else if attachment.hasItemConformingToTypeIdentifier(kUTTypeText as String) {
                    attachment.loadItem(forTypeIdentifier: kUTTypeText as String, options: nil) { [weak self] (item, error) in
                        DispatchQueue.main.async {
                            if let text = item as? String {
                                // Try to extract URL from text
                                if let url = URL(string: text) {
                                    self?.handleSharedURL(url)
                                } else {
                                    // Look for URLs in the text
                                    let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
                                    let matches = detector?.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
                                    if let firstMatch = matches?.first, let url = firstMatch.url {
                                        self?.handleSharedURL(url)
                                    }
                                }
                            }
                        }
                    }
                }
                // Handle images (for future enhancement)
                else if attachment.hasItemConformingToTypeIdentifier(kUTTypeImage as String) {
                    // For now, just complete the request
                    self?.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
                }
                // Handle movies (for future enhancement)
                else if attachment.hasItemConformingToTypeIdentifier(kUTTypeMovie as String) {
                    // For now, just complete the request
                    self?.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
                }
            }
        }
    }
    
    private func handleSharedURL(_ url: URL) {
        // Create a user activity to pass the URL to the main app
        let activity = NSUserActivity(activityType: "com.clipboard.addURL")
        activity.userInfo = ["url": url.absoluteString]
        activity.webpageURL = url
        
        // Complete the extension
        extensionContext?.completeRequest(returningItems: [], completionHandler: { _ in
            // The main app will handle the user activity
        })
    }
} 