//
//  AddItemView.swift
//  Clipboard
//
//  Created by Tamara Osseiran on 8/29/25.
//

import SwiftUI
import SwiftData
import MapKit
import CoreLocation

struct AddItemView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var title: String = ""
    @State private var description: String = ""
    @State private var url: String = ""
    @State private var selectedContentType: ContentType = .place
    @State private var address: String = ""
    @State private var city: String = ""
    @State private var state: String = ""
    @State private var country: String = ""
    @State private var latitude: String = ""
    @State private var longitude: String = ""
    @State private var notes: String = ""
    @State private var tags: String = ""
    @State private var rating: Double?
    @State private var isVisited: Bool = false
    @State private var isFavorite: Bool = false
    
    @State private var isGeocoding: Bool = false
    @State private var geocodingError: String?
    
    let prefilledURL: String?
    
    init(prefilledURL: String? = nil) {
        self.prefilledURL = prefilledURL
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Basic Information")) {
                    TextField("Title", text: $title)
                        .textInputAutocapitalization(.words)
                    
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                    
                    TextField("URL", text: $url)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                    
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
                
                Section(header: Text("Location")) {
                    TextField("Address", text: $address)
                        .textInputAutocapitalization(.words)
                    
                    HStack {
                        TextField("City", text: $city)
                        TextField("State", text: $state)
                    }
                    
                    TextField("Country", text: $country)
                    
                    HStack {
                        TextField("Latitude", text: $latitude)
                            .keyboardType(.decimalPad)
                        TextField("Longitude", text: $longitude)
                            .keyboardType(.decimalPad)
                    }
                    
                    if isGeocoding {
                        HStack {
                            ProgressView()
                            Text("Geocoding address...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if let error = geocodingError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    
                    Button("Geocode Address") {
                        geocodeAddress()
                    }
                    .disabled(address.isEmpty || isGeocoding)
                }
                
                Section(header: Text("Additional Information")) {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                    
                    TextField("Tags (comma-separated)", text: $tags)
                        .autocapitalization(.none)
                    
                    Stepper(value: Binding(
                        get: { rating ?? 0 },
                        set: { rating = $0 > 0 ? $0 : nil }
                    ), in: 0...5) {
                        HStack {
                            Text("Rating")
                            Spacer()
                            if let rating = rating {
                                HStack {
                                    ForEach(0..<5) { index in
                                        Image(systemName: index < Int(rating) ? "star.fill" : "star")
                                            .foregroundColor(.yellow)
                                    }
                                }
                            } else {
                                Text("Not rated")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    Toggle("Visited", isOn: $isVisited)
                    Toggle("Favorite", isOn: $isFavorite)
                }
            }
            .navigationTitle("Add Spot")
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
                    .fontWeight(.semibold)
                    .disabled(title.isEmpty)
                }
            }
            .onAppear {
                if let prefilledURL = prefilledURL {
                    self.url = prefilledURL
                    parsePrefilledURL()
                }
            }
        }
    }
    
    private func parsePrefilledURL() {
        guard let urlString = prefilledURL, let url = URL(string: urlString) else { return }
        
        let parsed = URLParser.parseURL(url)
        title = parsed.title
        description = parsed.description
        selectedContentType = parsed.contentType
        
        if let location = parsed.detectedLocation {
            address = location.address ?? ""
            city = location.city ?? ""
            state = location.state ?? ""
            country = location.country ?? ""
            if location.latitude != 0.0 || location.longitude != 0.0 {
                latitude = String(location.latitude)
                longitude = String(location.longitude)
            }
        }
        
        if !parsed.tags.isEmpty {
            tags = parsed.tags.joined(separator: ", ")
        }
    }
    
    private func geocodeAddress() {
        guard !address.isEmpty else { return }
        
        isGeocoding = true
        geocodingError = nil
        
        let geocoder = CLGeocoder()
        let fullAddress = [address, city, state, country]
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
        
        geocoder.geocodeAddressString(fullAddress) { placemarks, error in
            DispatchQueue.main.async {
                isGeocoding = false
                
                if let error = error {
                    geocodingError = "Geocoding failed: \(error.localizedDescription)"
                    return
                }
                
                guard let placemark = placemarks?.first,
                      let coordinate = placemark.location?.coordinate else {
                    geocodingError = "Could not find location"
                    return
                }
                
                latitude = String(coordinate.latitude)
                longitude = String(coordinate.longitude)
                
                // Update address fields from placemark
                if let street = placemark.thoroughfare {
                    address = street
                }
                if let cityName = placemark.locality {
                    city = cityName
                }
                if let stateName = placemark.administrativeArea {
                    state = stateName
                }
                if let countryName = placemark.country {
                    country = countryName
                }
            }
        }
    }
    
    private func saveItem() {
        // Create location if we have coordinates or address
        var location: Location? = nil
        
        if let lat = Double(latitude), let lon = Double(longitude), (lat != 0.0 || lon != 0.0) {
            location = Location(
                latitude: lat,
                longitude: lon,
                address: address.isEmpty ? nil : address,
                city: city.isEmpty ? nil : city,
                state: state.isEmpty ? nil : state,
                country: country.isEmpty ? nil : country
            )
        } else if !address.isEmpty {
            location = Location(
                latitude: 0.0,
                longitude: 0.0,
                address: address,
                city: city.isEmpty ? nil : city,
                state: state.isEmpty ? nil : state,
                country: country.isEmpty ? nil : country
            )
        }
        
        // Parse tags
        let tagArray = tags.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        let newItem = ContentItem(
            title: title,
            description: description.isEmpty ? nil : description,
            url: url.isEmpty ? nil : url,
            contentType: selectedContentType,
            location: location,
            rating: rating,
            isVisited: isVisited,
            isFavorite: isFavorite,
            notes: notes.isEmpty ? nil : notes,
            tags: tagArray
        )
        
        modelContext.insert(newItem)
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("❌ Failed to save item: \(error)")
        }
    }
}

#Preview {
    AddItemView()
        .modelContainer(for: ContentItem.self, inMemory: true)
}
