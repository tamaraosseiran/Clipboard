//
//  ContentView.swift
//  Clipboard
//
//  Created by Tamara Osseiran on 8/29/25.
//

import SwiftUI
import SwiftData
import MapKit
import CoreLocation

extension String: @retroactive Identifiable {
    public var id: String { self }
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [ContentItem]
    @State private var isMapView = true
    @State private var showingAddItem = false
    @State private var selectedFilter: ContentType? = nil
    @State private var sharedURL: String?
    @State private var showingSharedContentPreview = false
    @State private var pendingSharedContent: SharedContentPreview?
    @State private var sharedContent: SharedContent?
    
    var filteredItems: [ContentItem] {
        var filtered = items
        
        if let filter = selectedFilter {
            filtered = filtered.filter { $0.contentTypeEnum == filter }
        }
        
        return filtered.sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with view selector
                HStack {
                    // View selector
                    Menu {
                        Button(action: { isMapView = true }) {
                            HStack {
                                Image(systemName: "map")
                                Text("Map")
                                if isMapView {
                                    Spacer()
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                        
                        Button(action: { isMapView = false }) {
                            HStack {
                                Image(systemName: "list.bullet")
                                Text("Collections")
                                if !isMapView {
                                    Spacer()
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(isMapView ? "Map" : "Collections")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                            Image(systemName: "chevron.down")
                                .font(.title3)
                                .foregroundColor(.secondary)
                        }
                        .foregroundColor(.primary)
                    }
                    
                    Spacer()
                    
                    // Filter button
                    Menu {
                        Button("All Items") { selectedFilter = nil }
                        ForEach(ContentType.allCases, id: \.self) { type in
                            Button(type.rawValue) { selectedFilter = type }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.title)
                            .foregroundColor(.blue)
                    }
                    
                    // Add button
                    Button(action: { showingAddItem = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title)
                            .foregroundColor(.blue)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 4)
                .background(Color(.systemBackground))
                
                Divider()
                
                // Content
                if isMapView {
                    MapView(items: filteredItems)
                } else {
                    ListView(items: filteredItems, selectedFilter: $selectedFilter)
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .sheet(isPresented: $showingAddItem) {
            AddItemView()
        }
        .sheet(item: $sharedURL) { url in
            AddItemView(prefilledURL: url)
        }
        .sheet(isPresented: $showingSharedContentPreview) {
            if let content = pendingSharedContent {
                SharedContentPreviewView(
                    content: content,
                    onSave: { parsedContent in
                        saveSharedContent(parsedContent)
                        showingSharedContentPreview = false
                        pendingSharedContent = nil
                    },
                    onCancel: {
                        showingSharedContentPreview = false
                        pendingSharedContent = nil
                    }
                )
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("AddSharedURL"))) { notification in
            if let url = notification.userInfo?["url"] as? String {
                print("📱 Received shared URL via NotificationCenter: \(url)")
                
                // Show a simple alert to confirm the URL was received
                DispatchQueue.main.async {
                    // You can remove this alert later, it's just for debugging
                    let alert = UIAlertController(title: "URL Received!", message: "Received: \(url)", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let window = windowScene.windows.first {
                        window.rootViewController?.present(alert, animated: true)
                    }
                }
                
                processSharedURL(url)
            }
        }
        .onAppear {
            print("📱 ContentView appeared, checking for shared content...")
            checkAppGroupForSharedURLs()
            checkAppGroupForSharedContent()
        }
    }
    
    private func checkAppGroupForSharedURLs() {
        print("📱 Checking App Group for shared URLs...")
        guard let defaults = UserDefaults(suiteName: "group.com.tamaraosseiran.clipboard") else { 
            print("❌ Failed to access App Group UserDefaults")
            return 
        }
        
        if let inbox = defaults.array(forKey: "SharedURLInbox") as? [String], !inbox.isEmpty {
            print("📱 Found \(inbox.count) shared URLs in inbox: \(inbox)")
            
            // Show user feedback
            DispatchQueue.main.async {
                // You could add a toast or alert here if needed
                print("📱 Main app received \(inbox.count) shared URLs!")
            }
            
            // Get the first URL from the inbox
            if let firstURL = inbox.first {
                print("📱 Processing shared URL: \(firstURL)")
                processSharedURL(firstURL)
            }
            
            // Clear the inbox
            defaults.removeObject(forKey: "SharedURLInbox")
            defaults.synchronize()
            print("📱 Cleared inbox")
        } else {
            print("📱 No shared URLs found in inbox")
        }
    }
    
    private func processSharedURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        
        // Parse the URL to extract information
        let parsedURL = URLParser.parseURL(url)
        
        // Create a preview object for user validation
        let preview = SharedContentPreview(
            originalURL: urlString,
            title: parsedURL.title,
            description: parsedURL.description,
            contentType: parsedURL.contentType,
            detectedLocation: parsedURL.detectedLocation,
            tags: parsedURL.tags
        )
        
        // Show the preview for user validation
        pendingSharedContent = preview
        showingSharedContentPreview = true
    }
    
    private func checkAppGroupForSharedContent() {
        print("📱 Checking App Group for shared content...")
        guard let defaults = UserDefaults(suiteName: "group.com.tamaraosseiran.clipboard") else { 
            print("❌ Failed to access App Group UserDefaults")
            return 
        }
        
        if let contentData = defaults.array(forKey: "SharedContent") as? [Data], !contentData.isEmpty {
            print("📱 Found \(contentData.count) shared content items in inbox")
            
            // Process the most recent content
            if let latestContentData = contentData.last,
               let content = try? JSONDecoder().decode(SharedContent.self, from: latestContentData) {
                print("📱 Processing latest content: \(content.title)")
                processSharedContent(content)
                
                // Clear the processed content from the inbox
                let remainingContent = Array(contentData.dropLast())
                defaults.set(remainingContent, forKey: "SharedContent")
                defaults.synchronize()
            }
        }
    }
    
    private func processSharedContent(_ content: SharedContent) {
        print("📱 Processing shared content: \(content.title)")
        
        // Determine content type based on the source
        let contentType: ContentType
        switch content.contentType.lowercased() {
        case "video", "tiktok", "instagram":
            contentType = .other // User can change this
        case "restaurant", "yelp", "google maps":
            contentType = .restaurant
        case "place", "location":
            contentType = .place
        case "recipe", "cooking":
            contentType = .recipe
        case "shop", "store":
            contentType = .shop
        case "activity", "event":
            contentType = .activity
        default:
            contentType = .other
        }
        
        // Create a preview for the content
        let preview = SharedContentPreview(
            originalURL: content.url,
            title: content.title,
            description: content.description,
            contentType: contentType,
            detectedLocation: nil, // Will be detected from description
            tags: []
        )
        
        // Show the preview for user validation
        pendingSharedContent = preview
        showingSharedContentPreview = true
    }
    
    private func saveSharedContent(_ content: ParsedContent) {
        // Create a new ContentItem from the parsed content
        let newItem = ContentItem(
            title: content.title,
            description: content.description,
            url: content.originalURL,
            contentType: content.contentType,
            location: content.detectedLocation,
            rating: nil,
            isVisited: false,
            isFavorite: false,
            notes: content.description,
            tags: content.tags
        )
        
        modelContext.insert(newItem)
        
        do {
            try modelContext.save()
            print("✅ Successfully saved shared content: \(content.title)")
        } catch {
            print("❌ Failed to save shared content: \(error)")
        }
    }
}

// MARK: - Shared Content Preview Models
struct SharedContentPreview {
    let originalURL: String
    let title: String
    let description: String
    let contentType: ContentType
    let detectedLocation: Location?
    let tags: [String]
}

struct ParsedContent {
    let title: String
    let description: String
    let contentType: ContentType
    let originalURL: String
    let detectedLocation: Location?
    let tags: [String]
}

// MARK: - Shared Content Preview View
struct SharedContentPreviewView: View {
    let content: SharedContentPreview
    let onSave: (ParsedContent) -> Void
    let onCancel: () -> Void
    
    @State private var editedTitle: String
    @State private var editedDescription: String
    @State private var selectedContentType: ContentType
    @State private var editedLocation: String
    @State private var isEditingLocation = false
    
    init(content: SharedContentPreview, onSave: @escaping (ParsedContent) -> Void, onCancel: @escaping () -> Void) {
        self.content = content
        self.onSave = onSave
        self.onCancel = onCancel
        self._editedTitle = State(initialValue: content.title)
        self._editedDescription = State(initialValue: content.description)
        self._selectedContentType = State(initialValue: content.contentType)
        self._editedLocation = State(initialValue: content.detectedLocation?.displayAddress ?? "")
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Review Shared Content")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Check and edit the information before saving")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    
                    // Content Preview Card
                    VStack(alignment: .leading, spacing: 16) {
                        // Source URL
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Source")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                            
                            Text(content.originalURL)
                                .font(.caption)
                                .foregroundColor(.blue)
                                .lineLimit(2)
                        }
                        
                        Divider()
                        
                        // Title
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Title")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                            
                            TextField("Enter title", text: $editedTitle)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        
                        // Description
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Description")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                            
                            TextField("Enter description", text: $editedDescription, axis: .vertical)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .lineLimit(3...6)
                        }
                        
                        // Category
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Category")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                            
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
                        }
                        
                        // Location
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Location")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                            
                            if isEditingLocation {
                                TextField("Enter address", text: $editedLocation)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                            } else {
                                HStack {
                                    Text(editedLocation.isEmpty ? "No location detected" : editedLocation)
                                        .foregroundColor(editedLocation.isEmpty ? .secondary : .primary)
                                    
                                    Spacer()
                                    
                                    Button("Edit") {
                                        isEditingLocation = true
                                    }
                                    .font(.caption)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            }
                        }
                        
                        // Tags
                        if !content.tags.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Tags")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .textCase(.uppercase)
                                
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 8) {
                                    ForEach(content.tags, id: \.self) { tag in
                                        Text(tag)
                                            .font(.caption)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.blue.opacity(0.1))
                                            .foregroundColor(.blue)
                                            .cornerRadius(12)
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(radius: 2)
                    .padding(.horizontal)
                }
            }
            .navigationTitle("Add to Clipboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel", action: onCancel)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        let parsedContent = ParsedContent(
                            title: editedTitle,
                            description: editedDescription,
                            contentType: selectedContentType,
                            originalURL: content.originalURL,
                            detectedLocation: editedLocation.isEmpty ? nil : Location(
                                latitude: content.detectedLocation?.latitude ?? 0,
                                longitude: content.detectedLocation?.longitude ?? 0,
                                address: editedLocation
                            ),
                            tags: content.tags
                        )
                        onSave(parsedContent)
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - List View
struct ListView: View {
    let items: [ContentItem]
    @Binding var selectedFilter: ContentType?
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        List {
            ForEach(items) { item in
                NavigationLink(destination: ItemDetailView(item: item)) {
                    ItemRowView(item: item)
                }
            }
            .onDelete(perform: deleteItems)
        }
        .listStyle(InsetGroupedListStyle())
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(items[index])
            }
        }
    }
}

// MARK: - Item Row View
struct ItemRowView: View {
    let item: ContentItem
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Text(item.contentTypeEnum.icon)
                .font(.title2)
                .frame(width: 40, height: 40)
                .background(Color(item.contentTypeEnum.color).opacity(0.1))
                .clipShape(Circle())
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.headline)
                    .lineLimit(1)
                
                if let description = item.itemDescription {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                HStack {
                    Text(item.contentTypeEnum.rawValue)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color(item.contentTypeEnum.color).opacity(0.2))
                        .foregroundColor(Color(item.contentTypeEnum.color))
                        .clipShape(Capsule())
                    
                    if item.isVisited {
                        Text("✓ Visited")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                    
                    if item.isFavorite {
                        Image(systemName: "heart.fill")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    
                    Spacer()
                    
                    Text(item.createdAt, style: .date)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Map View
struct MapView: View {
    let items: [ContentItem]
    @Environment(\.modelContext) private var modelContext
    @StateObject private var locationManager = LocationManager()
    
    @State private var position: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    ))
    @State private var selectedItem: ContentItem?
    @State private var bottomSheetOffset: CGFloat = UIScreen.main.bounds.height * 0.5
    @State private var bottomSheetHeight: CGFloat = UIScreen.main.bounds.height * 0.5
    @State private var isDragging = false
    
    var body: some View {
        ZStack {
            Map(position: $position, selection: $selectedItem) {
                // Show user location
                if let userLocation = locationManager.location {
                    Annotation("My Location", coordinate: userLocation.coordinate) {
                        ZStack {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 12, height: 12)
                            Circle()
                                .stroke(Color.white, lineWidth: 3)
                                .frame(width: 16, height: 16)
                        }
                    }
                }
                
                // Show saved items as dots
                ForEach(itemsWithLocation) { item in
                    Annotation(item.title, coordinate: item.location!.coordinate) {
                        SimpleDotView(item: item)
                    }
                    .tag(item)
                }
            }
            .mapControls {
                MapCompass()
                MapUserLocationButton()
            }
            .onTapGesture {
                selectedItem = nil
            }
            
            VStack {
                Spacer()
                
                // Current Location Button
                HStack {
                    Spacer()
                    Button(action: {
                        centerOnUserLocation()
                    }) {
                        Image(systemName: "paperplane.fill")
                            .font(.title3)
                            .foregroundColor(.primary)
                            .frame(width: 44, height: 44)
                            .background(Color(.systemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .shadow(radius: 4)
                    }
                    .padding(.trailing, 16)
                    .padding(.bottom, max(bottomSheetOffset + 20, 20))
                }
                
                // Bottom Sheet
                BottomSheetView(
                    items: itemsWithLocation,
                    selectedItem: $selectedItem,
                    offset: $bottomSheetOffset,
                    height: $bottomSheetHeight,
                    isDragging: $isDragging
                )
            }
        }
        .sheet(item: $selectedItem) { item in
            ItemDetailView(item: item)
        }
    }
    
    private var itemsWithLocation: [ContentItem] {
        items.filter { $0.location != nil }
    }
    
    private func centerOnUserLocation() {
        guard let userLocation = locationManager.location else {
            locationManager.requestLocation()
            return
        }
        
        withAnimation {
            position = .camera(MapCamera(
                centerCoordinate: userLocation.coordinate,
                distance: 2000,
                heading: 0,
                pitch: 0
            ))
        }
    }
}

// MARK: - Location Manager
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var location: CLLocationCoordinate2D?
    
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        requestLocation()
    }
    
    func requestLocation() {
        guard manager.authorizationStatus != .denied else { return }
        manager.requestWhenInUseAuthorization()
        manager.requestLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        location = locations.first?.coordinate
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            manager.requestLocation()
        }
    }
}

// MARK: - Simple Dot View
struct SimpleDotView: View {
    let item: ContentItem
    
    var body: some View {
        Circle()
            .fill(Color.gray)
            .frame(width: 10, height: 10)
            .overlay(
                Circle()
                    .stroke(Color.white, lineWidth: 2)
                    .frame(width: 14, height: 14)
            )
    }
}

// MARK: - Bottom Sheet View
struct BottomSheetView: View {
    let items: [ContentItem]
    @Binding var selectedItem: ContentItem?
    @Binding var offset: CGFloat
    @Binding var height: CGFloat
    @Binding var isDragging: Bool
    
    @State private var dragOffset: CGFloat = 0
    @State private var showingAddItem = false
    @State private var selectedFilter: ContentType? = nil
    
    private let minHeight: CGFloat = 200
    private let maxHeight: CGFloat = UIScreen.main.bounds.height * 0.9
    
    var filteredItems: [ContentItem] {
        var filtered = items
        
        if let filter = selectedFilter {
            filtered = filtered.filter { $0.contentTypeEnum == filter }
        }
        
        return filtered.sorted { $0.createdAt > $1.createdAt }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Drag handle
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 40, height: 5)
                .padding(.top, 8)
            
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Spots")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text("\(filteredItems.count) spots")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Filter button
                Menu {
                    Button("All Items") { selectedFilter = nil }
                    ForEach(ContentType.allCases, id: \.self) { type in
                        Button(type.rawValue) { selectedFilter = type }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.title2)
                        .foregroundColor(.primary)
                }
                
                // Add button
                Button(action: { showingAddItem = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 8)
            
            // List of items
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(filteredItems) { item in
                        BottomSheetItemRow(item: item, selectedItem: $selectedItem)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 20)
            }
        }
        .frame(height: height)
        .background(
            Color(.systemBackground)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: -5)
        )
        .offset(y: offset + dragOffset)
        .gesture(
            DragGesture()
                .onChanged { value in
                    isDragging = true
                    let newOffset = offset + value.translation.height
                    
                    // Constrain dragging
                    if newOffset >= 0 && newOffset <= maxHeight - minHeight {
                        dragOffset = value.translation.height
                    }
                }
                .onEnded { value in
                    isDragging = false
                    let newOffset = offset + value.translation.height
                    let threshold = (maxHeight - minHeight) / 2
                    
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        if newOffset < threshold {
                            // Snap to top
                            offset = 0
                            height = maxHeight
                        } else {
                            // Snap to middle
                            offset = maxHeight - minHeight - 100
                            height = minHeight + 100
                        }
                        dragOffset = 0
                    }
                }
        )
        .sheet(isPresented: $showingAddItem) {
            AddItemView()
        }
    }
}

// MARK: - Bottom Sheet Item Row
struct BottomSheetItemRow: View {
    let item: ContentItem
    @Binding var selectedItem: ContentItem?
    
    var body: some View {
        Button(action: {
            selectedItem = item
        }) {
            HStack(spacing: 12) {
                // Placeholder for image
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray5))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Text(item.contentTypeEnum.icon)
                            .font(.title2)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    if item.isVisited {
                        Text("Last visited on \(item.createdAt, style: .date)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Not visited")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(spacing: 8) {
                        // Tags/Categories - show first 2 tags with icons
                        if !item.tags.isEmpty {
                            ForEach(item.tags.prefix(2), id: \.self) { tag in
                                HStack(spacing: 4) {
                                    if tag.lowercased().contains("matcha") || tag.lowercased().contains("tea") {
                                        Image(systemName: "cup.and.saucer.fill")
                                            .font(.caption2)
                                    } else {
                                        Image(systemName: "tag.fill")
                                            .font(.caption2)
                                    }
                                    Text(tag)
                                        .font(.caption2)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.green.opacity(0.1))
                                .foregroundColor(.green)
                                .cornerRadius(8)
                            }
                            if item.tags.count > 2 {
                                Text("+\(item.tags.count - 2)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // Content type tag with icon
                        HStack(spacing: 4) {
                            if item.contentTypeEnum == .restaurant {
                                Image(systemName: "cup.and.saucer.fill")
                                    .font(.caption2)
                            } else if item.contentTypeEnum == .shop {
                                Image(systemName: "bag.fill")
                                    .font(.caption2)
                            } else {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.caption2)
                            }
                            Text(item.contentTypeEnum.rawValue)
                                .font(.caption2)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(8)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Category Pin View
struct CategoryPinView: View {
    let item: ContentItem
    @Binding var selectedItem: ContentItem?
    
    var body: some View {
        VStack(spacing: 0) {
            // Main pin
            ZStack {
                // Pin shadow
                Circle()
                    .fill(Color.black.opacity(0.2))
                    .frame(width: 32, height: 32)
                    .offset(x: 2, y: 2)
                
                // Pin background
                Circle()
                    .fill(Color(item.contentTypeEnum.color))
                    .frame(width: 30, height: 30)
                
                // Icon
                Text(item.contentTypeEnum.icon)
                    .font(.system(size: 16, weight: .semibold))
            }
            
            // Pin tail
            Triangle()
                .fill(Color(item.contentTypeEnum.color))
                .frame(width: 12, height: 8)
                .offset(y: -2)
        }
        .scaleEffect(selectedItem?.id == item.id ? 1.2 : 1.0)
        .animation(.spring(response: 0.3), value: selectedItem?.id)
    }
}

// MARK: - Triangle Shape for Pin Tail
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

#Preview {
    ContentView()
        .modelContainer(for: ContentItem.self, inMemory: true)
}
