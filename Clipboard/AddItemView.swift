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
    
    @State private var title = ""
    @State private var description = ""
    @State private var url: String
    @State private var selectedContentType: ContentType = .other
    @State private var parsedURL: ParsedURL?
    @State private var detectedLocation: Location?
    @State private var isDetectingLocation = false
    @State private var showLocationApproval = false
    
    init(prefilledURL: String? = nil) {
        self.prefilledURL = prefilledURL
        _url = State(initialValue: prefilledURL ?? "")
    }
    @State private var selectedCategory: Category?
    @State private var rating: Int = 0
    @State private var isVisited = false
    @State private var isFavorite = false
    @State private var notes = ""
    @State private var tags = ""
    
    // Location fields
    @State private var hasLocation = false
    @State private var latitude = ""
    @State private var longitude = ""
    @State private var address = ""
    @State private var city = ""
    @State private var state = ""
    @State private var country = ""
    
    @Query private var categories: [Category]
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 20) {
                    basicInformationSection
                    categorySection
                    locationSection
                    statusSection
                    additionalInformationSection
                }
                .padding(.vertical)
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
                    .disabled(title.isEmpty)
                }
            }
        }
        .onAppear {
            if let prefilledURL = prefilledURL, !prefilledURL.isEmpty {
                url = prefilledURL
                parsedURL = URLParser.parseURL(prefilledURL)
                if let parsed = parsedURL {
                    title = parsed.title
                    description = parsed.description
                    selectedContentType = parsed.contentType
                    tags = parsed.tags.joined(separator: ", ")
                }
                
                // Automatically detect location for prefilled URLs
                Task {
                    await detectLocationFromURL(prefilledURL)
                }
            }
        }
    }
    
    private func saveItem() {
        let newItem = ContentItem(
            title: title,
            description: description.isEmpty ? nil : description,
            url: url.isEmpty ? nil : url,
            contentType: selectedContentType,
            location: hasLocation ? createLocation() : nil,
            category: selectedCategory,
            rating: rating > 0 ? rating : nil,
            isVisited: isVisited,
            isFavorite: isFavorite,
            notes: notes.isEmpty ? nil : notes,
            tags: tags.isEmpty ? [] : tags.split(separator: ",").map { String($0.trimmingCharacters(in: .whitespaces)) }
        )
        
        modelContext.insert(newItem)
        dismiss()
    }
    
    private func createLocation() -> Location? {
        guard let lat = Double(latitude), let lon = Double(longitude) else {
            return nil
        }
        
        return Location(
            latitude: lat,
            longitude: lon,
            address: address.isEmpty ? nil : address,
            city: city.isEmpty ? nil : city,
            state: state.isEmpty ? nil : state,
            country: country.isEmpty ? nil : country
        )
    }
    
    private func getCurrentLocation() {
        // This would integrate with CoreLocation
        // For now, we'll just show a placeholder
        // In a real app, you'd request location permissions and get the current location
    }
    
    private func detectLocationFromURL(_ urlString: String) async {
        isDetectingLocation = true
        
        if let location = await URLParser.detectLocation(from: urlString) {
            await MainActor.run {
                detectedLocation = location
                isDetectingLocation = false
                // Don't automatically enable location - let user decide
            }
        } else {
            await MainActor.run {
                isDetectingLocation = false
            }
        }
    }
    
    private func useDetectedLocation(_ location: Location) {
        // Populate the manual fields with detected location data
        address = location.address ?? ""
        city = location.city ?? ""
        state = location.state ?? ""
        country = location.country ?? ""
        latitude = String(location.latitude)
        longitude = String(location.longitude)
        
        // Enable location toggle since we have location data
        hasLocation = true
        
        // Clear the detected location since user approved it
        detectedLocation = nil
    }
    
    // MARK: - View Components
    
    private var basicInformationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Basic Information")
                .font(.headline)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                TextField("Title", text: $title)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                TextField("Description (optional)", text: $description, axis: .vertical)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .lineLimit(3...6)
                
                TextField("URL (optional)", text: $url)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.URL)
                    .autocapitalization(.none)
                    .onChange(of: url) { _, newValue in
                        if !newValue.isEmpty {
                            parsedURL = URLParser.parseURL(newValue)
                            if let parsed = parsedURL {
                                title = parsed.title
                                description = parsed.description
                                selectedContentType = parsed.contentType
                                tags = parsed.tags.joined(separator: ", ")
                            }
                            
                            // Automatically detect location
                            Task {
                                await detectLocationFromURL(newValue)
                            }
                        }
                    }
                
                Picker("Type", selection: $selectedContentType) {
                    ForEach(ContentType.allCases, id: \.self) { type in
                        HStack {
                            Image(systemName: type.icon)
                            Text(type.rawValue)
                        }
                        .tag(type)
                    }
                }
                .pickerStyle(MenuPickerStyle())
            }
            .padding(.horizontal)
        }
    }
    
    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Category")
                .font(.headline)
                .padding(.horizontal)
            
            Picker("Category", selection: $selectedCategory) {
                Text("None").tag(nil as Category?)
                ForEach(categories) { category in
                    HStack {
                        Image(systemName: category.icon)
                            .foregroundColor(Color(category.color))
                        Text(category.name)
                    }
                    .tag(category as Category?)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .padding(.horizontal)
        }
    }
    
    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Location")
                .font(.headline)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                Toggle("Has Location", isOn: $hasLocation)
                
                if hasLocation {
                    // Show detected location if available
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
                                .fontWeight(.medium)
                            
                            if let address = detectedLocation.address {
                                Text(address)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack {
                                Button("Use This Location") {
                                    useDetectedLocation(detectedLocation)
                                }
                                .buttonStyle(.borderedProminent)
                                
                                Button("Reject") {
                                    self.detectedLocation = nil
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    
                    // Manual location entry
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Manual Entry")
                            .font(.headline)
                        
                        TextField("Address", text: $address)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        TextField("City", text: $city)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        TextField("State/Province", text: $state)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        TextField("Country", text: $country)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        HStack {
                            TextField("Latitude", text: $latitude)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.decimalPad)
                            TextField("Longitude", text: $longitude)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.decimalPad)
                        }
                        
                        Button("Get Current Location") {
                            getCurrentLocation()
                        }
                        .foregroundColor(.blue)
                    }
                }
                
                // Location detection status
                if isDetectingLocation {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Detecting location...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Status")
                .font(.headline)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
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
            .padding(.horizontal)
        }
    }
    
    private var additionalInformationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Additional Information")
                .font(.headline)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                TextField("Notes", text: $notes, axis: .vertical)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .lineLimit(3...6)
                
                TextField("Tags (comma separated)", text: $tags)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
            }
            .padding(.horizontal)
        }
    }
}

#Preview {
    AddItemView()
        .modelContainer(for: ContentItem.self, inMemory: true)
} 