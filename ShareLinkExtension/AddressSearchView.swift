//
//  AddressSearchView.swift
//  ShareLinkExtension
//
//  Created for address autocomplete functionality
//

import SwiftUI
import MapKit
import CoreLocation

// MARK: - LocationSearchView (Full page search)
struct LocationSearchView: View {
    @Environment(\.dismiss) private var dismiss
    
    @Binding var selectedAddress: String
    @Binding var selectedLatitude: Double?
    @Binding var selectedLongitude: Double?
    var suggestions: [ResolvedPlace]
    
    @State private var searchText: String = ""
    @State private var searchCompleter = MKLocalSearchCompleter()
    @State private var searchResults: [MKLocalSearchCompletion] = []
    @State private var searchDelegate: AddressSearchDelegate?
    @State private var isSearchActive = false
    
    var body: some View {
        List {
            // Search field section
            Section {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search for a place or address", text: $searchText)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .onChange(of: searchText) { oldValue, newValue in
                            searchCompleter.queryFragment = newValue
                            isSearchActive = !newValue.isEmpty
                        }
                    
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                            isSearchActive = false
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            // Search results
            if isSearchActive && !searchResults.isEmpty {
                Section(header: Text("Search Results")) {
                    ForEach(searchResults.prefix(10), id: \.self) { result in
                        Button(action: {
                            selectSearchResult(result)
                        }) {
                            HStack {
                                Image(systemName: "mappin.circle.fill")
                                    .foregroundColor(.red)
                                    .font(.title2)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(result.title)
                                        .font(.body)
                                        .foregroundColor(.primary)
                                    if !result.subtitle.isEmpty {
                                        Text(result.subtitle)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                            }
                        }
                    }
                }
            }
            
            // Suggestions from enrichment (only show when not searching)
            if !isSearchActive && !suggestions.isEmpty {
                Section(header: Text("Suggested Places")) {
                    ForEach(suggestions, id: \.address) { place in
                        Button(action: {
                            selectSuggestion(place)
                        }) {
                            HStack {
                                Image(systemName: "sparkles")
                                    .foregroundColor(.blue)
                                    .font(.title2)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(place.name)
                                        .font(.body)
                                        .foregroundColor(.primary)
                                    Text(place.address)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                }
                                Spacer()
                            }
                        }
                    }
                }
            }
            
            // Current selection (if any)
            if !selectedAddress.isEmpty && !isSearchActive {
                Section(header: Text("Current Location")) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.title2)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(selectedAddress)
                                .font(.body)
                            if selectedLatitude != nil && selectedLongitude != nil {
                                Text("Coordinates saved")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                        }
                        Spacer()
                    }
                    
                    // Clear button
                    Button(role: .destructive) {
                        selectedAddress = ""
                        selectedLatitude = nil
                        selectedLongitude = nil
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("Remove Location")
                        }
                    }
                }
            }
        }
        .navigationTitle("Location")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            searchCompleter.resultTypes = [.address, .pointOfInterest]
            let delegate = AddressSearchDelegate(results: $searchResults, isSearching: .constant(true))
            searchDelegate = delegate
            searchCompleter.delegate = delegate
        }
    }
    
    private func selectSearchResult(_ completion: MKLocalSearchCompletion) {
        let request = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: request)
        
        search.start { response, error in
            if let error = error {
                print("⚠️ [LocationSearchView] Geocoding error: \(error.localizedDescription)")
                return
            }
            
            if let mapItem = response?.mapItems.first {
                DispatchQueue.main.async {
                    // Build full address from map item
                    let address = formatAddress(from: mapItem) ?? completion.title
                    self.selectedAddress = address
                    
                    var location: CLLocation?
                    if #available(iOS 26.0, *) {
                        location = mapItem.location
                    } else {
                        location = mapItem.placemark.location
                    }
                    
                    if let location = location {
                        self.selectedLatitude = location.coordinate.latitude
                        self.selectedLongitude = location.coordinate.longitude
                    }
                    
                    print("✅ [LocationSearchView] Selected: \(address)")
                    dismiss()
                }
            }
        }
    }
    
    private func selectSuggestion(_ place: ResolvedPlace) {
        selectedAddress = place.address
        selectedLatitude = place.latitude
        selectedLongitude = place.longitude
        print("✅ [LocationSearchView] Selected suggestion: \(place.name)")
        dismiss()
    }
    
    private func formatAddress(from mapItem: MKMapItem) -> String? {
        // Note: placemark is deprecated in iOS 26.0 but still functional
        let placemark = mapItem.placemark
        
        var parts: [String] = []
        if let name = mapItem.name {
            parts.append(name)
        }
        if let thoroughfare = placemark.thoroughfare {
            if let subThoroughfare = placemark.subThoroughfare {
                parts.append("\(subThoroughfare) \(thoroughfare)")
            } else {
                parts.append(thoroughfare)
            }
        }
        if let locality = placemark.locality {
            parts.append(locality)
        }
        if let administrativeArea = placemark.administrativeArea {
            parts.append(administrativeArea)
        }
        if let postalCode = placemark.postalCode {
            parts.append(postalCode)
        }
        
        // Remove duplicates while preserving order
        var seen = Set<String>()
        let uniqueParts = parts.filter { seen.insert($0).inserted }
        
        return uniqueParts.isEmpty ? nil : uniqueParts.joined(separator: ", ")
    }
}

// MARK: - AddressSearchView (Inline search - kept for compatibility)
struct AddressSearchView: View {
    @Binding var address: String
    @Binding var latitude: Double?
    @Binding var longitude: Double?
    
    @State private var searchText: String = ""
    @State private var searchCompleter = MKLocalSearchCompleter()
    @State private var searchResults: [MKLocalSearchCompletion] = []
    @State private var isSearching = false
    @State private var searchDelegate: AddressSearchDelegate?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField("Search for address", text: $searchText)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .onChange(of: searchText) { oldValue, newValue in
                    address = newValue
                    searchCompleter.queryFragment = newValue
                }
                .onAppear {
                    searchCompleter.resultTypes = [.address, .pointOfInterest]
                    let delegate = AddressSearchDelegate(results: $searchResults, isSearching: $isSearching)
                    searchDelegate = delegate
                    searchCompleter.delegate = delegate
                    if !address.isEmpty {
                        searchText = address
                    }
                }
            
            if isSearching && !searchResults.isEmpty {
                List(searchResults, id: \.self) { result in
                    Button(action: {
                        selectAddress(result)
                    }) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(result.title)
                                .font(.body)
                                .foregroundColor(.primary)
                            if !result.subtitle.isEmpty {
                                Text(result.subtitle)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .frame(maxHeight: 200)
            }
        }
    }
    
    private func selectAddress(_ completion: MKLocalSearchCompletion) {
        searchText = completion.title
        address = completion.title
        searchCompleter.queryFragment = ""
        
        // Geocode the selected address
        let request = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: request)
        
        search.start { response, error in
            if let error = error {
                print("⚠️ [AddressSearchView] Geocoding error: \(error.localizedDescription)")
                return
            }
            
            if let mapItem = response?.mapItems.first {
                var location: CLLocation?
                
                // Try placemark.location first (iOS < 26)
                // Note: placemark is deprecated in iOS 26.0, but still functional
                if #available(iOS 26.0, *) {
                    // Use new API for iOS 26+
                    location = mapItem.location
                } else {
                    // Use placemark for older iOS versions
                    location = mapItem.placemark.location
                }
                
                if let location = location {
                    DispatchQueue.main.async {
                        self.latitude = location.coordinate.latitude
                        self.longitude = location.coordinate.longitude
                        print("✅ [AddressSearchView] Selected address: \(completion.title) -> \(location.coordinate.latitude), \(location.coordinate.longitude)")
                    }
                }
            }
        }
    }
}

class AddressSearchDelegate: NSObject, MKLocalSearchCompleterDelegate {
    @Binding var results: [MKLocalSearchCompletion]
    @Binding var isSearching: Bool
    
    init(results: Binding<[MKLocalSearchCompletion]>, isSearching: Binding<Bool>) {
        _results = results
        _isSearching = isSearching
    }
    
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        DispatchQueue.main.async {
            self.results = completer.results
            self.isSearching = !completer.results.isEmpty && !completer.queryFragment.isEmpty
        }
    }
    
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        print("⚠️ [AddressSearchView] Search completer error: \(error.localizedDescription)")
    }
}

