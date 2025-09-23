//
//  ContentView.swift
//  Clipboard
//
//  Created by Tamara Osseiran on 8/29/25.
//

import SwiftUI
import SwiftData
import MapKit

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
                processSharedURL(url)
            }
        }
        .onAppear {
            print("📱 ContentView appeared, checking for shared URLs...")
            checkAppGroupForSharedURLs()
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
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )
    @State private var selectedItem: ContentItem?
    
    var body: some View {
        Map(position: .constant(.region(region)), selection: $selectedItem) {
            ForEach(itemsWithLocation) { item in
                Annotation(item.title, coordinate: item.location!.coordinate) {
                    CategoryPinView(item: item, selectedItem: $selectedItem)
                }
                .tag(item)
            }
        }
        .sheet(item: $selectedItem) { item in
            ItemDetailView(item: item)
        }
    }
    
    private var itemsWithLocation: [ContentItem] {
        items.filter { $0.location != nil }
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
