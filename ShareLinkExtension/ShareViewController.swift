//
//  ShareViewController.swift
//  ShareLinkExtension
//
//  Created by Tamara Osseiran on 9/22/25.
//

import UIKit
import SwiftUI
import UniformTypeIdentifiers
import OSLog
import CoreLocation
import MapKit

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
            if let windowScene = view.window?.windowScene {
                view.frame = windowScene.screen.bounds
            } else {
                view.frame = CGRect(x: 0, y: 0, width: 375, height: 600)
            }
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
    
    @State private var latitude: Double?
    @State private var longitude: Double?
    
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var hasContent = false
    
    // New: enrichment-related state
    @State private var categoryConfidence: EnrichedContent.CategoryConfidence = .low
    @State private var alternatePlaces: [ResolvedPlace] = []
    @State private var showingAlternates = false
    @State private var extractedKeywords: [String] = []
    @State private var customCategory: String = ""  // For user-created categories
    
    // Computed: do we have a confirmed location with coordinates?
    private var hasConfirmedLocation: Bool {
        !location.isEmpty && latitude != nil && longitude != nil
    }
    
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
                        
                        // Location - NavigationLink to search subpage
                        NavigationLink {
                            LocationSearchView(
                                selectedAddress: $location,
                                selectedLatitude: $latitude,
                                selectedLongitude: $longitude,
                                suggestions: alternatePlaces
                            )
                        } label: {
                            HStack {
                                Text("Location")
                                    .foregroundColor(.primary)
                                Spacer()
                                if hasConfirmedLocation {
                                    Text(location)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                        .frame(maxWidth: 180, alignment: .trailing)
                                } else {
                                    Text("Add Location")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        
                        // Category - NavigationLink to category selection page
                        NavigationLink {
                            CategorySelectionView(
                                selectedType: $selectedContentType,
                                customCategory: $customCategory,
                                suggestedKeywords: extractedKeywords,
                                confidence: categoryConfidence
                            )
                        } label: {
                            HStack {
                                Text("Category")
                                    .foregroundColor(.primary)
                                Spacer()
                                HStack(spacing: 4) {
                                    Text(selectedContentType.icon)
                                    Text(customCategory.isEmpty ? selectedContentType.rawValue : customCategory)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        
                        // Show why we suggested this category
                        if categoryConfidence == .high && !extractedKeywords.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "sparkles")
                                    .font(.caption2)
                                    .foregroundColor(.blue)
                                Text("Suggested based on: \(extractedKeywords.prefix(3).joined(separator: ", "))")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
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
    
    // MARK: - Select Alternate Place
    private func selectAlternatePlace(_ place: ResolvedPlace) {
        print("🔵 [ShareRootView] Selected alternate place: \(place.name)")
        self.name = place.name
        self.location = place.address
        self.latitude = place.latitude
        self.longitude = place.longitude
        
        // Clear alternates since user made a selection
        self.alternatePlaces = []
    }
    
    // MARK: - Parse Content (Enhanced with ContentEnricher)
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
        
        // Check for attributed content text (often contains caption from social media apps)
        if let attributedText = firstItem.attributedContentText {
            print("📝 [ShareRootView] Found attributedContentText: \(attributedText.string)")
        }
        
        // Check userInfo for additional data
        if let userInfo = firstItem.userInfo {
            print("📦 [ShareRootView] UserInfo keys: \(userInfo.keys)")
            for (key, value) in userInfo {
                print("📦 [ShareRootView] UserInfo[\(key)]: \(value)")
            }
        }
        
        // Log all type identifiers for debugging
        for (index, provider) in attachments.enumerated() {
            let types = provider.registeredTypeIdentifiers
            print("📋 [ShareRootView] Attachment \(index + 1) types: \(types.joined(separator: ", "))")
        }
        
        // Try to load ALL content types from ALL attachments
        var foundURL: URL?
        var foundText: String?
        let group = DispatchGroup()
        
        // First, check attributedContentText - social media apps often put caption here
        if let attributedText = firstItem.attributedContentText?.string, !attributedText.isEmpty {
            print("📝 [ShareRootView] Using attributedContentText as initial text: \(attributedText)")
            foundText = attributedText
        }
        
        // Load from ALL attachments - don't break early
        for (index, provider) in attachments.enumerated() {
            // Try URL type
            if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                print("🔗 [ShareRootView] Attachment \(index+1) has URL type, loading...")
                group.enter()
                provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { item, error in
                    defer { group.leave() }
                    
                    if let error = error {
                        print("❌ [ShareRootView] Error loading URL: \(error.localizedDescription)")
                        return
                    }
                    
                    if let url = item as? URL {
                        print("✅ [ShareRootView] Loaded URL: \(url.absoluteString)")
                        if foundURL == nil {
                            foundURL = url
                        }
                    } else if let urlString = item as? String, let url = URL(string: urlString) {
                        print("✅ [ShareRootView] Loaded URL from string: \(url.absoluteString)")
                        if foundURL == nil {
                            foundURL = url
                        }
                    } else {
                        print("⚠️ [ShareRootView] URL item is unexpected type: \(type(of: item))")
                    }
                }
            }
            
            // Try plain text type
            if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                print("📝 [ShareRootView] Attachment \(index+1) has plain text type, loading...")
                group.enter()
                provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { item, error in
                    defer { group.leave() }
                    
                    if let error = error {
                        print("❌ [ShareRootView] Error loading text: \(error.localizedDescription)")
                        return
                    }
                    
                    if let text = item as? String {
                        print("✅ [ShareRootView] Loaded text (\(text.count) chars): \(text)")
                        // Append to existing text or set it
                        if let existing = foundText {
                            foundText = existing + "\n" + text
                        } else {
                            foundText = text
                        }
                        
                        // Try to extract URL from text if we don't have one
                        if foundURL == nil, let url = extractURL(from: text) {
                            print("✅ [ShareRootView] Extracted URL from text: \(url.absoluteString)")
                            foundURL = url
                        }
                    } else if let data = item as? Data, let text = String(data: data, encoding: .utf8) {
                        print("✅ [ShareRootView] Loaded text from data (\(text.count) chars): \(text)")
                        if let existing = foundText {
                            foundText = existing + "\n" + text
                        } else {
                            foundText = text
                        }
                        
                        if foundURL == nil, let url = extractURL(from: text) {
                            foundURL = url
                        }
                    }
                }
            }
            
            // Also try UTType.text as fallback
            if provider.hasItemConformingToTypeIdentifier(UTType.text.identifier) && 
               !provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                print("📝 [ShareRootView] Attachment \(index+1) has text type, loading...")
                group.enter()
                provider.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { item, error in
                    defer { group.leave() }
                    
                    if let error = error {
                        print("❌ [ShareRootView] Error loading text: \(error.localizedDescription)")
                        return
                    }
                    
                    if let text = item as? String {
                        print("✅ [ShareRootView] Loaded text via UTType.text (\(text.count) chars): \(text)")
                        if let existing = foundText {
                            foundText = existing + "\n" + text
                        } else {
                            foundText = text
                        }
                    }
                }
            }
        }
        
        // Wait for async loads to complete
        group.notify(queue: .main) {
            print("🔵 [ShareRootView] All loads completed")
            print("🔵 [ShareRootView] URL: \(foundURL?.absoluteString ?? "nil"), Text: \(foundText?.prefix(50) ?? "nil")...")
            
            if let url = foundURL {
                self.sourceURL = url.absoluteString
            }
            
            // First fetch HTML metadata if we have a URL
            if let url = foundURL {
                let candidate = SharedCandidate(
                    sourceURL: url,
                    rawText: foundText,
                    movieFileURL: nil,
                    imageFileURL: nil
                )
                
                // Fetch HTML metadata first (this also fetches oEmbed for TikTok/Instagram)
                MetadataFetcher.buildDraft(from: candidate, logger: self.logger) { draft in
                    // Now use ContentEnricher to enhance the results
                    var structuredCoords: (lat: Double, lon: Double)? = nil
                    if let lat = draft.latitude, let lon = draft.longitude {
                        structuredCoords = (lat, lon)
                    }
                    
                    // Check if we got a caption from oEmbed (TikTok/Instagram)
                    // The oEmbed caption is stored in MetadataFetcher.lastFetchedCaption
                    let oembedCaption = MetadataFetcher.lastFetchedCaption
                    print("📝 [ShareRootView] oEmbed caption: \(oembedCaption ?? "nil")")
                    
                    // Use oEmbed caption as text if we don't have other text
                    let textToEnrich = foundText ?? oembedCaption
                    
                    ContentEnricher.enrich(
                        url: url,
                        text: textToEnrich,
                        htmlTitle: draft.name,
                        htmlDescription: oembedCaption, // Pass oEmbed caption as description too
                        structuredAddress: draft.address,
                        structuredCoordinates: structuredCoords
                    ) { enriched in
                        DispatchQueue.main.async {
                            self.applyEnrichedContent(enriched)
                        }
                    }
                }
            } else if let text = foundText {
                // No URL, just text - use ContentEnricher directly
                ContentEnricher.enrich(
                    url: nil,
                    text: text,
                    htmlTitle: nil,
                    htmlDescription: nil,
                    structuredAddress: nil,
                    structuredCoordinates: nil
                ) { enriched in
                    DispatchQueue.main.async {
                        self.applyEnrichedContent(enriched)
                    }
                }
            } else {
                // No content found
                self.isLoading = false
                self.hasContent = true
                print("⚠️ [ShareRootView] No URL or text found - showing empty form")
            }
        }
        
        // Timeout after 5 seconds - always show form (increased from 3s for enrichment)
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            if self.isLoading {
                print("⏱️ [ShareRootView] Parse timeout - showing form anyway")
                self.isLoading = false
                self.hasContent = true
            }
        }
    }
    
    // MARK: - Apply Enriched Content to UI
    private func applyEnrichedContent(_ enriched: EnrichedContent) {
        print("✅ [ShareRootView] Applying enriched content")
        print("   Name: \(enriched.name)")
        print("   Category: \(enriched.suggestedCategory.rawValue) (confidence: \(enriched.categoryConfidence))")
        print("   Primary place: \(enriched.primaryPlace?.name ?? "none")")
        print("   Alternates: \(enriched.alternatePlaces.count)")
        
        // Apply name
        self.name = enriched.name
        
        // Apply notes
        if let notes = enriched.notes, !notes.isEmpty {
            self.note = notes
        }
        
        // Apply category
        self.selectedContentType = enriched.suggestedCategory
        self.categoryConfidence = enriched.categoryConfidence
        self.extractedKeywords = enriched.extractedKeywords
        
        // Apply primary place
        if let place = enriched.primaryPlace {
            self.location = place.address
            self.latitude = place.latitude
            self.longitude = place.longitude
            
            // Use place name if it's better than what we have
            if place.name.count > enriched.name.count && !place.name.lowercased().contains("shared") {
                self.name = place.name
            }
        }
        
        // Store alternates for user selection
        self.alternatePlaces = enriched.alternatePlaces
        
        // Apply source URL
        if let sourceURL = enriched.sourceURL {
            self.sourceURL = sourceURL
        }
        
        self.isLoading = false
        self.hasContent = true
        print("✅ [ShareRootView] UI updated with enriched content")
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
    
    // MARK: - Extract Address from Text
    private func extractAddressFromText(_ text: String) -> String? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.address.rawValue)
        let range = NSRange(text.startIndex..., in: text)
        if let match = detector?.firstMatch(in: text, options: [], range: range),
           let addressRange = Range(match.range, in: text) {
            return String(text[addressRange])
        }
        return nil
    }
    
    // MARK: - Geocode Address
    // Note: This function is now primarily used as a fallback.
    // AddressSearchView handles geocoding automatically when users select an address.
    @available(iOS, deprecated: 26.0, message: "CLGeocoder is deprecated, but still functional. AddressSearchView uses MKLocalSearch which is preferred.")
    private func geocodeAddress(_ address: String) {
        guard !address.isEmpty else { return }
        
        // Note: CLGeocoder is deprecated in iOS 26.0, but still functional
        // Using it for consistency with the main app until MapKit replacement is stable
        // This is only used as a fallback - AddressSearchView uses MKLocalSearch which is preferred
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(address) { placemarks, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("⚠️ [ShareRootView] Geocoding error: \(error.localizedDescription)")
                    return
                }
                
                if let placemark = placemarks?.first,
                   let location = placemark.location {
                    self.latitude = location.coordinate.latitude
                    self.longitude = location.coordinate.longitude
                    print("✅ [ShareRootView] Geocoded address: \(address) -> \(self.latitude!), \(self.longitude!)")
                } else {
                    print("⚠️ [ShareRootView] No coordinates found for address: \(address)")
                }
            }
        }
    }
    
    // MARK: - Save Spot
    private func saveSpot() {
        // Use custom category if set, otherwise use selected type
        let categoryToSave = customCategory.isEmpty ? selectedContentType.rawValue : customCategory
        
        print("💾 [ShareRootView] Saving spot...")
        print("   Name: \(name)")
        print("   Location: \(location)")
        print("   URL: \(sourceURL)")
        print("   Category: \(categoryToSave)")
        
        guard let defaults = UserDefaults(suiteName: "group.com.tamaraosseiran.clipboard") else {
            print("❌ [ShareRootView] Cannot access App Group")
            errorMessage = "Cannot access shared storage"
            return
        }
        
        // Create spot data matching the format main app expects
        var spotData: [String: Any] = [
            "name": name,
            "address": location,
            "sourceURL": sourceURL,
            "contentType": categoryToSave,
            "notes": note,
            "createdAt": Date().timeIntervalSince1970
        ]
        
        // If using custom category, flag it for the main app to create if needed
        if !customCategory.isEmpty {
            spotData["isCustomCategory"] = true
        }
        
        // Add coordinates if available
        if let lat = latitude, let lon = longitude {
            spotData["latitude"] = lat
            spotData["longitude"] = lon
            print("💾 [ShareRootView] Including coordinates: \(lat), \(lon)")
        }
        
        // Save to App Group
        if let data = try? JSONSerialization.data(withJSONObject: spotData) {
            defaults.set(data, forKey: "pending_spot")
            defaults.set(Date().timeIntervalSince1970, forKey: "last_shared_timestamp")
            defaults.synchronize()
            print("✅ [ShareRootView] Saved to App Group")
            print("✅ [ShareRootView] Data size: \(data.count) bytes")
            
            // Try to open main app
            // In app extensions, we can't use UIApplication.shared
            // The main app will be opened when the extension completes
            print("🔵 [ShareRootView] Will open main app via URL scheme: spots://import")
            
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
