import Foundation

// Utility for the MAIN APP target to fetch URLs saved by the ShareLinkExtension.
// Ensure this file is added to the main app target (it can also be shared to the extension if you prefer).

struct SharedInboxReader {
    static func fetchAndClear() -> [String] {
        guard let defaults = UserDefaults(suiteName: AppGroup.identifier) else { return [] }
        let urls = defaults.array(forKey: SharedKeys.inbox) as? [String] ?? []
        defaults.removeObject(forKey: SharedKeys.inbox)
        defaults.synchronize()
        return urls
    }
}
