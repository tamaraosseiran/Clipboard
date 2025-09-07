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
    
    var filteredItems: [ContentItem] {
        var filtered = items
        
        if let filter = selectedFilter {
            filtered = filtered.filter { $0.contentTypeEnum == filter }
        }
        
        return filtered.sorted { $0.createdAt > $1.createdAt }
    }
    
    var body: some View {
        ZStack {
            // Full screen content
            if isMapView {
                MapView(items: filteredItems)
            } else {
                ListView(items: filteredItems, selectedFilter: $selectedFilter)
            }
            
            // Floating bottom menu
            VStack {
                Spacer()
                
                HStack(spacing: 0) {
                    // Add button
                    Button(action: { showingAddItem = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title)
                            .foregroundColor(.white)
                            .frame(width: 50, height: 50)
                            .background(Color.blue)
                            .clipShape(Circle())
                            .shadow(radius: 4)
                    }
                    
                    Spacer()
                    
                    // View toggle buttons
                    HStack(spacing: 8) {
                        Button(action: { isMapView = true }) {
                            HStack(spacing: 6) {
                                Image(systemName: "map")
                                Text("Map")
                            }
                            .foregroundColor(isMapView ? .white : .primary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(isMapView ? Color.blue : Color(.systemBackground))
                            .cornerRadius(20)
                            .shadow(radius: 2)
                        }
                        
                        Button(action: { isMapView = false }) {
                            HStack(spacing: 6) {
                                Image(systemName: "list.bullet")
                                Text("List")
                            }
                            .foregroundColor(isMapView ? .primary : .white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(isMapView ? Color(.systemBackground) : Color.blue)
                            .cornerRadius(20)
                            .shadow(radius: 2)
                        }
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
                            .foregroundColor(.white)
                            .frame(width: 50, height: 50)
                            .background(Color.gray)
                            .clipShape(Circle())
                            .shadow(radius: 4)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .ignoresSafeArea()
        .sheet(isPresented: $showingAddItem) {
            AddItemView()
        }
        .sheet(item: $sharedURL) { url in
            AddItemView(prefilledURL: url)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("AddSharedURL"))) { notification in
            if let url = notification.userInfo?["url"] as? String {
                sharedURL = url
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


// MARK: - Categories View
struct CategoriesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var categories: [Category]
    @State private var showingAddCategory = false
    
    var body: some View {
        List {
            ForEach(categories) { category in
                NavigationLink(destination: CategoryDetailView(category: category)) {
                    HStack {
                        Image(systemName: category.icon)
                            .foregroundColor(Color(category.color))
                            .frame(width: 30)
                        
                        Text(category.name)
                        
                        Spacer()
                        
                        Text("\(category.items?.count ?? 0)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .onDelete(perform: deleteCategories)
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingAddCategory = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddCategory) {
            AddCategoryView()
        }
    }
    
    private func deleteCategories(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(categories[index])
            }
        }
    }
}

// MARK: - Stats View
struct StatsView: View {
    let items: [ContentItem]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                StatCard(title: "Total Items", value: "\(items.count)", icon: "list.bullet", color: .blue)
                StatCard(title: "Visited", value: "\(items.filter { $0.isVisited }.count)", icon: "checkmark.circle", color: .green)
                StatCard(title: "Favorites", value: "\(items.filter { $0.isFavorite }.count)", icon: "heart", color: .red)
                StatCard(title: "Rated", value: "\(items.filter { $0.rating != nil }.count)", icon: "star", color: .yellow)
            }
            .padding()
            
            // Content Type Breakdown
            VStack(alignment: .leading, spacing: 12) {
                Text("By Type")
                    .font(.headline)
                    .padding(.horizontal)
                
                ForEach(ContentType.allCases, id: \.self) { type in
                    let count = items.filter { $0.contentTypeEnum == type }.count
                    HStack {
                        Text(type.icon)
                            .font(.title3)
                            .frame(width: 20)
                        
                        Text(type.rawValue)
                        
                        Spacer()
                        
                        Text("\(count)")
                            .fontWeight(.semibold)
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
}

// MARK: - Stat Card
struct StatCard: View {
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
                .font(.title)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: ContentItem.self, inMemory: true)
}
