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
    @State private var selectedContentType: ContentType = .other
    @State private var visitDates: [Date] = []
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
                    Picker("Category", selection: $selectedContentType) {
                        ForEach(ContentType.allCases, id: \.self) { type in
                            HStack {
                                Text(type.icon)
                                    .font(.title2)
                                    .frame(width: 30, alignment: .leading)
                                Text(type.rawValue)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .tag(type)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                } header: {
                    Text("Category")
                }
                
                Section {
                    TextField("Enter full address for map pinning", text: $location)
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
                            
                            Button("Use This Address") {
                                location = detectedLocation.displayAddress
                                self.detectedLocation = nil
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("Location")
                } footer: {
                    Text("Enter a full address so it can be pinned on the map")
                }
                
                Section {
                    Button(action: addCheckIn) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.blue)
                            Text("Check In")
                                .foregroundColor(.blue)
                        }
                    }
                    
                    if !visitDates.isEmpty {
                        ForEach(visitDates.indices, id: \.self) { index in
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text(visitDates[index], style: .date)
                                Spacer()
                                Button("Remove") {
                                    visitDates.remove(at: index)
                                }
                                .foregroundColor(.red)
                                .font(.caption)
                            }
                        }
                    }
                    
                    if !visitDates.isEmpty {
                        HStack {
                            Text("Overall Rating")
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
                    Text("Check-ins")
                } footer: {
                    Text("Tap 'Check In' to record each visit")
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
                // Parse URL and auto-fill name and category
                if let parsed = URLParser.parseURL(prefilledURL) {
                    name = parsed.title
                    selectedContentType = parsed.contentType
                    location = parsed.detectedLocation?.displayAddress ?? ""
                }
                
                // Trigger location detection for prefilled URL
                Task {
                    await detectLocationFromURL(prefilledURL)
                }
            }
        }
    }
    
    private func addCheckIn() {
        visitDates.append(Date())
    }
    
    private func saveItem() {
        let newItem = ContentItem(
            title: name,
            description: nil,
            url: prefilledURL,
            contentType: selectedContentType,
            location: location.isEmpty ? nil : createLocationFromString(location),
            category: nil,
            rating: rating > 0 ? rating : nil,
            isVisited: !visitDates.isEmpty,
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