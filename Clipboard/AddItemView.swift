//
//  AddItemView.swift
//  Clipboard
//
//  Created by Tamara Osseiran on 8/29/25.
//

import SwiftUI
import SwiftData
import CoreLocation

struct AddItemView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var location = ""
    @State private var selectedContentType: ContentType = .other
    @State private var visitDates: [Date] = []
    @State private var rating = 0
    @State private var note = ""
    
    let prefilledURL: String?
    
    init(prefilledURL: String? = nil) {
        self.prefilledURL = prefilledURL
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Name", text: $name)
                    TextField("Address", text: $location)
                    
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
                } header: {
                    Text("Basic Information")
                }
                
                Section {
                    Button(action: addCheckIn) {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                            Text("Check In")
                                .font(.body)
                                .fontWeight(.medium)
                        }
                    }
                    
                    if !visitDates.isEmpty {
                        ForEach(visitDates.indices, id: \.self) { index in
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(visitDates[index], style: .date)
                                        .font(.body)
                                    Text(visitDates[index], style: .time)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Button(action: {
                                    visitDates.remove(at: index)
                                }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                        .font(.title3)
                                }
                                .buttonStyle(.plain)
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
                    Text("Notes")
                }
            }
            .navigationTitle("Add Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel", action: dismiss.callAsFunction)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save", action: saveItem)
                        .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            if let urlString = prefilledURL {
                parseURL(urlString)
            }
        }
    }
    
    private func parseURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        
        let parsedURL = URLParser.parseURL(url)
        
        name = parsedURL.title
        selectedContentType = parsedURL.contentType
        
        if let detectedLocation = parsedURL.detectedLocation {
            location = detectedLocation.displayAddress
        }
    }
    
    private func addCheckIn() {
        visitDates.append(Date())
    }
    
    private func saveItem() {
        let newItem = ContentItem(
            title: name,
            description: note,
            url: prefilledURL,
            contentType: selectedContentType,
            location: location.isEmpty ? nil : Location(latitude: 0, longitude: 0, address: location),
            rating: rating > 0 ? rating : nil,
            isVisited: !visitDates.isEmpty,
            isFavorite: false,
            notes: note,
            tags: []
        )
        
        modelContext.insert(newItem)
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("Failed to save item: \(error)")
        }
    }
}

#Preview {
    AddItemView()
        .modelContainer(for: ContentItem.self, inMemory: true)
}
