import Foundation

// MARK: - Shared Content Model for Share Extension

struct SharedContent: Codable {
    let url: String
    let title: String
    let description: String
    let contentType: String
    let timestamp: Date
}
