//
//  CategoryViews.swift
//  Clipboard
//
//  Created by Tamara Osseiran on 8/29/25.
//

import SwiftUI
import SwiftData

// MARK: - Category Detail View
struct CategoryDetailView: View {
    let category: Category
    @Environment(\.modelContext) private var modelContext
    @Query private var allItems: [ContentItem]
    
    var categoryItems: [ContentItem] {
        allItems.filter { $0.category?.id == category.id }
    }
    
    var body: some View {
        List {
            Section {
                HStack {
                    Image(systemName: category.icon)
                        .font(.title2)
                        .foregroundColor(Color(category.color))
                        .frame(width: 40, height: 40)
                        .background(Color(category.color).opacity(0.1))
                        .clipShape(Circle())
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(category.name)
                            .font(.headline)
                        
                        Text("\(categoryItems.count) items")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(.vertical, 8)
            }
            
            Section("Items") {
                if categoryItems.isEmpty {
                    Text("No items in this category")
                        .foregroundColor(.secondary)
                        .italic()
                } else {
                    ForEach(categoryItems) { item in
                        NavigationLink(destination: ItemDetailView(item: item)) {
                            ItemRowView(item: item)
                        }
                    }
                }
            }
        }
        .navigationTitle(category.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Add Category View
struct AddCategoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var selectedColor = "blue"
    @State private var selectedIcon = "tag.circle.fill"
    
    let colors = ["blue", "red", "green", "orange", "purple", "pink", "yellow", "gray"]
    let icons = [
        "tag.circle.fill",
        "folder.circle.fill",
        "bookmark.circle.fill",
        "star.circle.fill",
        "heart.circle.fill",
        "flag.circle.fill",
        "location.circle.fill",
        "person.circle.fill",
        "house.circle.fill",
        "car.circle.fill",
        "airplane.circle.fill",
        "gamecontroller.circle.fill",
        "camera.circle.fill",
        "music.note.circle.fill",
        "tv.circle.fill",
        "cart.circle.fill"
    ]
    
    var body: some View {
        NavigationView {
            Form {
                Section("Basic Information") {
                    TextField("Category Name", text: $name)
                }
                
                Section("Color") {
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 50))
                    ], spacing: 12) {
                        ForEach(colors, id: \.self) { color in
                            Button(action: { selectedColor = color }) {
                                Circle()
                                    .fill(Color(color))
                                    .frame(width: 40, height: 40)
                                    .overlay(
                                        Circle()
                                            .stroke(selectedColor == color ? Color.primary : Color.clear, lineWidth: 3)
                                    )
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                Section("Icon") {
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 50))
                    ], spacing: 12) {
                        ForEach(icons, id: \.self) { icon in
                            Button(action: { selectedIcon = icon }) {
                                Image(systemName: icon)
                                    .font(.title2)
                                    .foregroundColor(selectedIcon == icon ? Color(selectedColor) : .gray)
                                    .frame(width: 40, height: 40)
                                    .background(selectedIcon == icon ? Color(selectedColor).opacity(0.1) : Color.clear)
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle()
                                            .stroke(selectedIcon == icon ? Color(selectedColor) : Color.clear, lineWidth: 2)
                                    )
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                Section("Preview") {
                    HStack {
                        Image(systemName: selectedIcon)
                            .font(.title2)
                            .foregroundColor(Color(selectedColor))
                            .frame(width: 40, height: 40)
                            .background(Color(selectedColor).opacity(0.1))
                            .clipShape(Circle())
                        
                        Text(name.isEmpty ? "Category Name" : name)
                            .font(.headline)
                        
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("New Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveCategory()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
    
    private func saveCategory() {
        let newCategory = Category(
            name: name,
            color: selectedColor,
            icon: selectedIcon
        )
        
        modelContext.insert(newCategory)
        dismiss()
    }
}

#Preview {
    NavigationView {
        CategoryDetailView(category: Category(name: "Sample Category", color: "blue", icon: "tag.circle.fill"))
    }
    .modelContainer(for: ContentItem.self, inMemory: true)
} 