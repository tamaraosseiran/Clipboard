//
//  Location.swift
//  Clipboard
//
//  Created by Tamara Osseiran on 8/29/25.
//

import Foundation
import SwiftData
import CoreLocation

@Model
final class Location {
    var latitude: Double = 0.0
    var longitude: Double = 0.0
    var address: String?
    var city: String?
    var state: String?
    var country: String?
    
    init(latitude: Double = 0.0, longitude: Double = 0.0, address: String? = nil, city: String? = nil, state: String? = nil, country: String? = nil) {
        self.latitude = latitude
        self.longitude = longitude
        self.address = address
        self.city = city
        self.state = state
        self.country = country
    }
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    var displayAddress: String {
        var components: [String] = []
        
        if let address = address, !address.isEmpty {
            components.append(address)
        }
        if let city = city, !city.isEmpty {
            components.append(city)
        }
        if let state = state, !state.isEmpty {
            components.append(state)
        }
        if let country = country, !country.isEmpty {
            components.append(country)
        }
        
        return components.isEmpty ? "Unknown Location" : components.joined(separator: ", ")
    }
}
