//
//  AddItemView.swift
//  Clipboard
//
//  Created by Tamara Osseiran on 8/29/25.
//

import SwiftUI
import SwiftData
import MapKit

struct AddItemView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let prefilledURL: String?
    
    @State private var name = ""
    @State private var location = ""
    @State private var isVisited = false
    @State private var visitDate = Date()
    @State private var rating = 0
    @State private var note = ""
    
    // For location detection
    @State private var detectedLocation: Location?
    @State private var isDetectingLocation = false
    
    init(prefilledURL: String? = nil) {
        self.prefilledURL = prefilledURL
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Name", text: $name)
                        .textFieldStyle(.plain)
                } header: {
                    Text("Name")
                }
                
                Section {
                    TextField("Location", text: $location)
                        .textFieldStyle(.plain)
                    
                    if let detectedLocation = detectedLocation {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "mappin.circle.fill")
                                    .foregroundColor(.red)
                                Text("Detected Location")
                                    .font(.headline)
                            }
                            
                            Text(detectedLocation.displayAddress)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Button("Use This Location") {
                                location = detectedLocation.displayAddress
                                self.detectedLocation = nil
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("Location")
                }
                
                Section {
                    Toggle("Visited", isOn: $isVisited)
                    
                    if isVisited {
                        DatePicker("Visit Date", selection: $visitDate, displayedComponents: .date)
                        
                        HStack {
                            Text("Rating")
                            Spacer()
                            ForEach(1...5, id: \.self) { star in
                                Button(action: { rating = star }) {
                                    Image(systemName: star <= rating ? "star.fill" : "star")
                                        .foregroundColor(star <= rating ? .yellow : .gray)
                                        .font(.title2)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Visit Status")
                }
                
                Section {
                    TextField("Note", text: $note, axis: .vertical)
                        .lineLimit(3...6)
                } header: {
                    Text("Note")
                }
            }
            .navigationTitle("Add Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveItem()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
        .onAppear {
            if let prefilledURL = prefilledURL, !prefilledURL.isEmpty {
                // Parse URL and auto-fill name
                if let parsed = URLParser.parseURL(prefilledURL) {
                    name = parsed.title
                    location = parsed.detectedLocation?.displayAddress ?? ""
                }
                
                // Trigger location detection for prefilled URL
                Task {
                    await detectLocationFromURL(prefilledURL)
                }
            }
        }
    }
    
    private func saveItem() {
        let newItem = ContentItem(
            title: name,
            description: nil,
            url: prefilledURL,
            contentType: .other, // Default to other since we removed category selection
            location: location.isEmpty ? nil : createLocationFromString(location),
            category: nil,
            rating: rating > 0 ? rating : nil,
            isVisited: isVisited,
            isFavorite: false,
            notes: note.isEmpty ? nil : note,
            tags: []
        )
        
        modelContext.insert(newItem)
        dismiss()
    }
    
    private func createLocationFromString(_ locationString: String) -> Location? {
        // For now, create a simple location with just the address
        // In a real app, you'd geocode this string to get coordinates
        return Location(
            latitude: 0.0, // Placeholder
            longitude: 0.0, // Placeholder
            address: locationString
        )
    }
    
    private func detectLocationFromURL(_ urlString: String) async {
        isDetectingLocation = true
        
        if let location = await URLParser.detectLocation(from: urlString) {
            await MainActor.run {
                detectedLocation = location
                isDetectingLocation = false
            }
        } else {
            await MainActor.run {
                isDetectingLocation = false
            }
        }
    }
}

#Preview {
    AddItemView()
}