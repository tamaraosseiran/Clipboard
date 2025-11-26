//
//  ItemDetailView.swift
//  Clipboard
//
//  Created by Tamara Osseiran on 8/29/25.
//

import SwiftUI
import SwiftData
import MapKit
import CoreLocation

struct ItemDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Bindable var item: ContentItem
    @State private var isEditing = false
    @State private var showingDeleteConfirmation = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header with icon and title
                HStack(alignment: .top, spacing: 16) {
                    // Icon
                    Text(item.contentTypeEnum.icon)
                        .font(.system(size: 50))
                        .frame(width: 80, height: 80)
                        .background(Color(item.contentTypeEnum.color).opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(item.title)
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text(item.contentTypeEnum.rawValue)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(Color(item.contentTypeEnum.color).opacity(0.2))
                            .foregroundColor(Color(item.contentTypeEnum.color))
                            .clipShape(Capsule())
                        
                        HStack {
                            if item.isVisited {
                                Label("Visited", systemImage: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                            
                            if item.isFavorite {
                                Label("Favorite", systemImage: "heart.fill")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    
                    Spacer()
                }
                .padding()
                
                Divider()
                
                // Description
                if let description = item.itemDescription, !description.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text(description)
                            .font(.body)
                    }
                    .padding(.horizontal)
                }
                
                // URL
                if let urlString = item.url, !urlString.isEmpty, let url = URL(string: urlString) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Source")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Link(urlString, destination: url)
                            .font(.body)
                    }
                    .padding(.horizontal)
                }
                
                // Location
                if let location = item.location {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Location")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                        
                        // Map
                        Map(initialPosition: .region(MKCoordinateRegion(
                            center: location.coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                        ))) {
                            Annotation(item.title, coordinate: location.coordinate) {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.title)
                                    .foregroundColor(.red)
                            }
                        }
                        .frame(height: 200)
                        .cornerRadius(12)
                        .padding(.horizontal)
                        
                        // Address
                        Text(location.displayAddress)
                            .font(.body)
                            .padding(.horizontal)
                    }
                }
                
                // Rating
                if let rating = item.rating {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Rating")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            ForEach(0..<5) { index in
                                Image(systemName: index < Int(rating) ? "star.fill" : "star")
                                    .foregroundColor(.yellow)
                            }
                            Text(String(format: "%.1f", rating))
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Tags
                if !item.tags.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tags")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 8) {
                            ForEach(item.tags, id: \.self) { tag in
                                Text(tag)
                                    .font(.caption)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.blue.opacity(0.1))
                                    .foregroundColor(.blue)
                                    .cornerRadius(12)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Notes
                if let notes = item.notes, !notes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text(notes)
                            .font(.body)
                    }
                    .padding(.horizontal)
                }
                
                // Metadata
                VStack(alignment: .leading, spacing: 4) {
                    Text("Created")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(item.createdAt, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.top)
            }
            .padding(.vertical)
        }
        .navigationTitle("Spot Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: {
                        item.isFavorite.toggle()
                    }) {
                        Label(item.isFavorite ? "Remove from Favorites" : "Add to Favorites", 
                              systemImage: item.isFavorite ? "heart.slash" : "heart.fill")
                    }
                    
                    Button(action: {
                        item.isVisited.toggle()
                    }) {
                        Label(item.isVisited ? "Mark as Not Visited" : "Mark as Visited",
                              systemImage: item.isVisited ? "xmark.circle" : "checkmark.circle")
                    }
                    
                    Divider()
                    
                    Button(role: .destructive, action: {
                        showingDeleteConfirmation = true
                    }) {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .alert("Delete Spot", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteItem()
            }
        } message: {
            Text("Are you sure you want to delete this spot? This action cannot be undone.")
        }
    }
    
    private func deleteItem() {
        modelContext.delete(item)
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("❌ Failed to delete item: \(error)")
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: ContentItem.self, configurations: config)
    
    let sampleItem = ContentItem(
        title: "Sample Coffee Shop",
        description: "A great place for coffee",
        url: "https://example.com",
        contentType: .restaurant,
        location: Location(latitude: 37.7749, longitude: -122.4194, address: "123 Main St", city: "San Francisco", state: "CA", country: "USA"),
        rating: 4.5,
        isVisited: true,
        isFavorite: false,
        notes: "Great atmosphere!",
        tags: ["coffee", "wifi", "quiet"]
    )
    
    return NavigationView {
        ItemDetailView(item: sampleItem)
    }
    .modelContainer(container)
}
