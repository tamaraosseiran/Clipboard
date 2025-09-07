//
//  ItemDetailView.swift
//  Clipboard
//
//  Created by Tamara Osseiran on 8/29/25.
//

import SwiftUI
import SwiftData
import MapKit

struct ItemDetailView: View {
    let item: ContentItem
    @Environment(\.modelContext) private var modelContext
    @State private var showingEditSheet = false
    @State private var showingMap = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(item.contentTypeEnum.icon)
                            .font(.largeTitle)
                            .frame(width: 60, height: 60)
                            .background(Color(item.contentTypeEnum.color).opacity(0.1))
                            .clipShape(Circle())
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title)
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text(item.contentTypeEnum.rawValue)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color(item.contentTypeEnum.color).opacity(0.2))
                                .foregroundColor(Color(item.contentTypeEnum.color))
                                .clipShape(Capsule())
                        }
                        
                        Spacer()
                        
                        VStack {
                            Button(action: { toggleFavorite() }) {
                                Image(systemName: item.isFavorite ? "heart.fill" : "heart")
                                    .font(.title2)
                                    .foregroundColor(item.isFavorite ? .red : .gray)
                            }
                            
                            Button(action: { toggleVisited() }) {
                                Image(systemName: item.isVisited ? "checkmark.circle.fill" : "circle")
                                    .font(.title2)
                                    .foregroundColor(item.isVisited ? .green : .gray)
                            }
                        }
                    }
                    
                    if let description = item.itemDescription {
                        Text(description)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(radius: 2)
                
                // Status Cards
                HStack(spacing: 12) {
                    StatusCard(
                        title: "Status",
                        value: item.statusText,
                        icon: item.isVisited ? "checkmark.circle.fill" : "circle",
                        color: item.isVisited ? .green : .gray
                    )
                    
                    StatusCard(
                        title: "Rating",
                        value: item.ratingText,
                        icon: "star.fill",
                        color: item.rating != nil ? .yellow : .gray
                    )
                }
                
                // Location Section
                if let location = item.location {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "location.circle.fill")
                                .foregroundColor(.blue)
                            Text("Location")
                                .font(.headline)
                            Spacer()
                            Button("View Map") {
                                showingMap = true
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                        }
                        
                        Text(location.displayAddress)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(radius: 2)
                }
                
                // Category Section
                if let category = item.category {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: category.icon)
                                .foregroundColor(Color(category.color))
                            Text("Category")
                                .font(.headline)
                            Spacer()
                        }
                        
                        Text(category.name)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(radius: 2)
                }
                
                // URL Section
                if let url = item.url {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "link.circle.fill")
                                .foregroundColor(.blue)
                            Text("Link")
                                .font(.headline)
                            Spacer()
                        }
                        
                        Link(destination: URL(string: url) ?? URL(string: "https://example.com")!) {
                            Text(url)
                                .font(.body)
                                .foregroundColor(.blue)
                                .lineLimit(2)
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(radius: 2)
                }
                
                // Tags Section
                if !item.tags.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "tag.circle.fill")
                                .foregroundColor(.purple)
                            Text("Tags")
                                .font(.headline)
                            Spacer()
                        }
                        
                        LazyVGrid(columns: [
                            GridItem(.adaptive(minimum: 80))
                        ], spacing: 8) {
                            ForEach(item.tags, id: \.self) { tag in
                                Text(tag)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.purple.opacity(0.2))
                                    .foregroundColor(.purple)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(radius: 2)
                }
                
                // Notes Section
                if let notes = item.notes {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "note.text.circle.fill")
                                .foregroundColor(.orange)
                            Text("Notes")
                                .font(.headline)
                            Spacer()
                        }
                        
                        Text(notes)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(radius: 2)
                }
                
                // Metadata
                VStack(alignment: .leading, spacing: 8) {
                    Text("Created: \(item.createdAt, style: .date)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Updated: \(item.updatedAt, style: .date)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top)
            }
            .padding()
        }
        .navigationTitle("Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit") {
                    showingEditSheet = true
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            EditItemView(item: item)
        }
        .sheet(isPresented: $showingMap) {
            if let location = item.location {
                LocationMapView(location: location, title: item.title)
            }
        }
    }
    
    private func toggleFavorite() {
        item.isFavorite.toggle()
        item.updatedAt = Date()
    }
    
    private func toggleVisited() {
        item.isVisited.toggle()
        item.updatedAt = Date()
    }
}

// MARK: - Status Card
struct StatusCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.headline)
                .fontWeight(.semibold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

// MARK: - Location Map View
struct LocationMapView: View {
    let location: Location
    let title: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Map(position: .constant(.region(MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            ))), selection: .constant(nil)) {
                Marker(title, coordinate: location.coordinate)
                    .tint(.red)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Edit Item View
struct EditItemView: View {
    let item: ContentItem
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var title: String
    @State private var description: String
    @State private var url: String
    @State private var selectedContentType: ContentType
    @State private var rating: Int
    @State private var isVisited: Bool
    @State private var isFavorite: Bool
    @State private var notes: String
    @State private var tags: String
    
    init(item: ContentItem) {
        self.item = item
        _title = State(initialValue: item.title)
        _description = State(initialValue: item.itemDescription ?? "")
        _url = State(initialValue: item.url ?? "")
        _selectedContentType = State(initialValue: item.contentTypeEnum)
        _rating = State(initialValue: item.rating ?? 0)
        _isVisited = State(initialValue: item.isVisited)
        _isFavorite = State(initialValue: item.isFavorite)
        _notes = State(initialValue: item.notes ?? "")
        _tags = State(initialValue: item.tags.joined(separator: ", "))
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Basic Information") {
                    TextField("Title", text: $title)
                    
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                    
                    TextField("URL", text: $url)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                    
                    Picker("Type", selection: $selectedContentType) {
                        ForEach(ContentType.allCases, id: \.self) { type in
                            HStack {
                                Text(type.icon)
                                    .font(.title2)
                                Text(type.rawValue)
                            }
                            .tag(type)
                        }
                    }
                }
                
                Section("Status") {
                    Toggle("Visited", isOn: $isVisited)
                    Toggle("Favorite", isOn: $isFavorite)
                    
                    if isVisited {
                        HStack {
                            Text("Rating")
                            Spacer()
                            ForEach(1...5, id: \.self) { star in
                                Button(action: { rating = star }) {
                                    Image(systemName: star <= rating ? "star.fill" : "star")
                                        .foregroundColor(star <= rating ? .yellow : .gray)
                                }
                            }
                        }
                    }
                }
                
                Section("Additional Information") {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                    
                    TextField("Tags (comma separated)", text: $tags)
                        .autocapitalization(.none)
                }
            }
            .navigationTitle("Edit Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveChanges()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }
    
    private func saveChanges() {
        item.title = title
        item.itemDescription = description.isEmpty ? nil : description
        item.url = url.isEmpty ? nil : url
        item.contentType = selectedContentType.rawValue
        item.rating = rating > 0 ? rating : nil
        item.isVisited = isVisited
        item.isFavorite = isFavorite
        item.notes = notes.isEmpty ? nil : notes
        item.tags = tags.isEmpty ? [] : tags.split(separator: ",").map { String($0.trimmingCharacters(in: .whitespaces)) }
        item.updatedAt = Date()
        
        dismiss()
    }
}

#Preview {
    NavigationView {
        ItemDetailView(item: ContentItem(title: "Sample Restaurant", description: "A great place to eat", contentType: .restaurant))
    }
    .modelContainer(for: ContentItem.self, inMemory: true)
} 