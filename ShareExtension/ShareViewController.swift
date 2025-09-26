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
                if attachment.hasItemConformingToTypeIdentifier(kUTTypeURL as String) {
                    attachment.loadItem(forTypeIdentifier: kUTTypeURL as String, options: nil) { [weak self] (item, error) in
                        DispatchQueue.main.async {
                            if let url = item as? URL {
                                self?.handleSharedURL(url)
                            }
                        }
                    }
                } else if attachment.hasItemConformingToTypeIdentifier(kUTTypeText as String) {
                    attachment.loadItem(forTypeIdentifier: kUTTypeText as String, options: nil) { [weak self] (item, error) in
                        DispatchQueue.main.async {
                            if let text = item as? String, let url = URL(string: text) {
                                self?.handleSharedURL(url)
                            }
                        }
                    }
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