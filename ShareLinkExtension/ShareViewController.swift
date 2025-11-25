import UIKit
import SwiftUI
import UniformTypeIdentifiers
import OSLog

// MARK: - ShareViewController (UIViewController wrapper)
final class ShareViewController: UIViewController {
    private let log = Logger(subsystem: "com.tamaraosseiran.clipboard.share", category: "Share")

    override func viewDidLoad() {
        super.viewDidLoad()
        print("🔵 [ShareViewController] viewDidLoad - Extension launched")
        log.info("Share extension launched")

        // Set preferred content size for share extension modal
        preferredContentSize = CGSize(width: 375, height: 600)
        print("🔵 [ShareViewController] Set preferredContentSize to \(preferredContentSize)")

        // Ensure we have a valid frame
        if view.frame.isEmpty {
            view.frame = UIScreen.main.bounds
            print("🔵 [ShareViewController] Set view frame to screen bounds")
        }

        view.backgroundColor = .systemBackground
        view.isOpaque = true
        
        // Create SwiftUI view with extension context
        let rootView = ShareRootView(context: extensionContext, logger: log)
        let hostingController = UIHostingController(rootView: rootView)
        
        addChild(hostingController)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        hostingController.view.backgroundColor = .systemBackground
        view.addSubview(hostingController.view)
        
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        hostingController.didMove(toParent: self)
        print("🔵 [ShareViewController] SwiftUI view added, frame: \(view.frame)")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        print("🔵 [ShareViewController] viewWillAppear")
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        print("🔵 [ShareViewController] viewDidAppear, frame: \(view.frame)")
    }
}

// MARK: - ShareRootView (Main SwiftUI View)
struct ShareRootView: View {
    let context: NSExtensionContext?
    let logger: Logger
    
    @State private var name: String = ""
    @State private var location: String = ""
    @State private var selectedContentType: ContentType = .place
    @State private var note: String = ""
    @State private var sourceURL: String = ""
    
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var hasContent = false
    
    var body: some View {
        NavigationView {
            if isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                    Text("Reading content…")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onAppear {
                    print("🔵 [ShareRootView] Loading view appeared - starting parse")
                    parseContent()
                }
            } else {
                Form {
                    Section(header: Text("Basic Information")) {
                        TextField("Name", text: $name)
                            .textInputAutocapitalization(.words)
                        
                        TextField("Address", text: $location)
                            .textInputAutocapitalization(.words)
                        
                        Picker("Category", selection: $selectedContentType) {
                            ForEach(ContentType.allCases, id: \.self) { type in
                                HStack {
                                    Text(type.icon)
                                        .font(.title2)
                                        .frame(width: 25)
                                    Text(type.rawValue)
                                        .font(.body)
                                }
                                .tag(type)
                            }
                        }
                        .pickerStyle(NavigationLinkPickerStyle())
                        
                        if !sourceURL.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Source URL")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(sourceURL)
                                            .font(.footnote)
                                    .foregroundColor(.secondary)
                                            .lineLimit(2)
                                    }
                                }
                            }
                    
                    Section(header: Text("Notes")) {
                        TextField("Note", text: $note, axis: .vertical)
                            .lineLimit(3...6)
                        }
                        
                    if let error = errorMessage {
                        Section {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            }
                        }
                    }
                    .navigationTitle("Add to Spots")
                    .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            print("🔵 [ShareRootView] User tapped Cancel")
                            complete(cancelled: true)
                        }
                    }
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Save") {
                            print("🔵 [ShareRootView] User tapped Save")
                            saveSpot()
                        }
                        .fontWeight(.semibold)
                        .disabled(name.isEmpty)
                    }
                }
            }
        }
        .onAppear {
            print("🔵 [ShareRootView] View appeared, isLoading=\(isLoading), hasContent=\(hasContent)")
        }
    }
    
    // MARK: - Parse Content (Simplified, Direct Approach)
    private func parseContent() {
        print("🔵 [ShareRootView] parseContent() called")
        guard let ctx = context else {
            print("❌ [ShareRootView] No extension context")
            DispatchQueue.main.async {
                errorMessage = "No extension context available"
                isLoading = false
            }
            return
        }
        
        print("📦 [ShareRootView] Got extension context, checking inputItems...")
        print("📦 [ShareRootView] inputItems count: \(ctx.inputItems.count)")
        
        guard let firstItem = ctx.inputItems.first as? NSExtensionItem else {
            print("❌ [ShareRootView] No input items or wrong type")
            DispatchQueue.main.async {
                errorMessage = "No shareable content found"
                isLoading = false
            }
            return
        }
        
        guard let attachments = firstItem.attachments, !attachments.isEmpty else {
            print("❌ [ShareRootView] No attachments found")
                        DispatchQueue.main.async {
                errorMessage = "No attachments in shared content"
                isLoading = false
            }
            return
        }
        
        print("✅ [ShareRootView] Found \(attachments.count) attachment(s)")
        
        // Log all type identifiers for debugging
        for (index, provider) in attachments.enumerated() {
            let types = provider.registeredTypeIdentifiers
            print("📋 [ShareRootView] Attachment \(index + 1) types: \(types.joined(separator: ", "))")
        }
        
        // Try to load URL first, then text
        var foundURL: URL?
        var foundText: String?
        let group = DispatchGroup()
        
        // Try URL
        for provider in attachments {
            if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                print("🔗 [ShareRootView] Found URL type, loading...")
                group.enter()
                provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { item, error in
                    defer { group.leave() }
                    
                    if let error = error {
                        print("❌ [ShareRootView] Error loading URL: \(error.localizedDescription)")
                        return
                    }
                    
                    if let url = item as? URL {
                        print("✅ [ShareRootView] Loaded URL: \(url.absoluteString)")
                        foundURL = url
                    } else if let urlString = item as? String, let url = URL(string: urlString) {
                        print("✅ [ShareRootView] Loaded URL from string: \(url.absoluteString)")
                        foundURL = url
                    } else {
                        print("⚠️ [ShareRootView] URL item is unexpected type: \(type(of: item))")
                    }
                }
                break // Take first URL
            }
        }
        
        // Try plain text (if no URL found or as fallback)
        if foundURL == nil {
            for provider in attachments {
                if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    print("📝 [ShareRootView] Found plain text type, loading...")
                    group.enter()
                    provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { item, error in
                        defer { group.leave() }
                        
                        if let error = error {
                            print("❌ [ShareRootView] Error loading text: \(error.localizedDescription)")
                            return
                        }
                        
                        if let text = item as? String {
                            print("✅ [ShareRootView] Loaded text: \(text.prefix(100))...")
                            foundText = text
                            
                            // Try to extract URL from text
                            if let url = extractURL(from: text) {
                                print("✅ [ShareRootView] Extracted URL from text: \(url.absoluteString)")
                                foundURL = url
                            }
                        } else if let data = item as? Data, let text = String(data: data, encoding: .utf8) {
                            print("✅ [ShareRootView] Loaded text from data: \(text.prefix(100))...")
                            foundText = text
                            
                            if let url = extractURL(from: text) {
                                foundURL = url
                            }
                        }
                    }
                    break // Take first text
                }
            }
        }
        
        // Wait for async loads to complete
        group.notify(queue: .main) {
            print("🔵 [ShareRootView] All loads completed")
            
            // Always show the form, even if we didn't find content
            self.isLoading = false
            self.hasContent = true
            
            // Update UI with found content
            if let url = foundURL {
                self.sourceURL = url.absoluteString
                self.name = url.host ?? (url.lastPathComponent.isEmpty ? "Shared Link" : url.lastPathComponent)
                if self.name.isEmpty {
                    self.name = "Shared Link"
                }
                self.location = url.absoluteString
                print("✅ [ShareRootView] UI updated with URL: \(url.absoluteString)")
            } else if let text = foundText {
                self.name = "Shared Text"
                self.location = text
                print("✅ [ShareRootView] UI updated with text")
            } else {
                print("⚠️ [ShareRootView] No URL or text found - showing empty form")
                // Show form with empty fields so user can enter manually
                if self.name.isEmpty {
                    self.name = ""
                }
            }
        }
        
        // Timeout after 3 seconds - always show form
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            if self.isLoading {
                print("⏱️ [ShareRootView] Parse timeout - showing form anyway")
                self.isLoading = false
                self.hasContent = true
                if self.name.isEmpty {
                    self.name = ""
                }
            }
        }
    }
    
    // MARK: - Extract URL from text
    private func extractURL(from text: String) -> URL? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let range = NSRange(text.startIndex..., in: text)
        if let match = detector?.firstMatch(in: text, options: [], range: range),
           let urlRange = Range(match.range, in: text) {
            return URL(string: String(text[urlRange]))
        }
        return nil
    }
    
    // MARK: - Save Spot
    private func saveSpot() {
        print("💾 [ShareRootView] Saving spot...")
        print("   Name: \(name)")
        print("   Location: \(location)")
        print("   URL: \(sourceURL)")
        print("   Category: \(selectedContentType.rawValue)")
        
        guard let defaults = UserDefaults(suiteName: "group.com.tamaraosseiran.clipboard") else {
            print("❌ [ShareRootView] Cannot access App Group")
            errorMessage = "Cannot access shared storage"
            return
        }
        
        // Create spot data matching the format main app expects
        let spotData: [String: Any] = [
            "name": name,
            "address": location,
            "sourceURL": sourceURL,
            "contentType": selectedContentType.rawValue,
            "notes": note,
            "createdAt": Date().timeIntervalSince1970
        ]
        
        // Save to App Group
        if let data = try? JSONSerialization.data(withJSONObject: spotData) {
            defaults.set(data, forKey: "pending_spot")
            defaults.set(Date().timeIntervalSince1970, forKey: "last_shared_timestamp")
            defaults.synchronize()
            print("✅ [ShareRootView] Saved to App Group")
            print("✅ [ShareRootView] Data size: \(data.count) bytes")
            
            // Try to open main app
            if let url = URL(string: "spots://import") {
                var responder: UIResponder? = self
                while responder != nil {
                    if let application = responder as? UIApplication {
                        application.open(url, options: [:], completionHandler: { success in
                            print("🔵 [ShareRootView] Open URL result: \(success)")
                        })
                        break
                    }
                    responder = responder?.next
                }
            }
            
            // Small delay to ensure data is written, then complete
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            complete(cancelled: false)
            }
        } else {
            print("❌ [ShareRootView] Failed to serialize spot data")
            errorMessage = "Failed to save"
        }
    }
    
    // MARK: - Complete Extension
    private func complete(cancelled: Bool) {
        print("🔵 [ShareRootView] Completing extension (cancelled: \(cancelled))")
        guard let ctx = context else {
            print("⚠️ [ShareRootView] No context to complete")
            return
        }
        ctx.completeRequest(returningItems: nil, completionHandler: { expired in
            if expired {
                print("⚠️ [ShareRootView] Extension request expired")
            } else {
                print("✅ [ShareRootView] Extension completed successfully")
            }
        })
    }
}
