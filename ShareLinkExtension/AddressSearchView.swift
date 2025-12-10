//
//  AddressSearchView.swift
//  ShareLinkExtension
//
//  Created for address autocomplete functionality
//

import SwiftUI
import MapKit
import CoreLocation

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

