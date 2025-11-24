import Foundation
import UniformTypeIdentifiers
import OSLog

enum ShareParserError: Error {
    case noItems
    case noSupportedPayload
}

struct SharedCandidate {
    var sourceURL: URL?
    var rawText: String?
    var movieFileURL: URL?
    var imageFileURL: URL?
}

enum ShareParser {
    static func parse(from context: NSExtensionContext, logger: Logger, completion: @escaping (Result<SharedCandidate, Error>) -> Void) {
        print("🔵 [ShareParser] Starting parse...")
        logger.info("Starting parse from extension context")
        
        guard let item = context.inputItems.first as? NSExtensionItem else {
            logger.error("No input items found")
            print("❌ [ShareParser] No input items found")
            completion(.failure(ShareParserError.noItems))
            return
        }
        
        guard let providers = item.attachments, !providers.isEmpty else {
            logger.error("No attachments found in input item")
            print("❌ [ShareParser] No attachments found")
            completion(.failure(ShareParserError.noItems))
            return
        }
        
        logger.info("Parsing \(providers.count) item provider(s)")
        print("📦 [ShareParser] Found \(providers.count) provider(s)")
        
        // Log all available type identifiers
        for (index, provider) in providers.enumerated() {
            let identifiers = provider.registeredTypeIdentifiers
            print("📋 [ShareParser] Provider \(index + 1) types: \(identifiers.joined(separator: ", "))")
            logger.info("Provider \(index + 1) types: \(identifiers.joined(separator: ", "))")
        }
        
        // Prevent multiple completions
        var hasCompleted = false
        let safeCompletion: (Result<SharedCandidate, Error>) -> Void = { result in
            guard !hasCompleted else { return }
            hasCompleted = true
            completion(result)
        }
        
        // Helper loaders
        func tryURL(_ provider: NSItemProvider, _ next: @escaping () -> Void) {
            if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                logger.info("Provider has URL type")
                print("🔗 [ShareParser] Loading URL from provider...")
                provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { item, error in
                    if let error = error {
                        logger.error("Error loading URL: \(error.localizedDescription)")
                        print("❌ [ShareParser] Error loading URL: \(error.localizedDescription)")
                        next()
                        return
                    }
                    if let url = item as? URL {
                        logger.info("Found URL: \(url.absoluteString)")
                        print("✅ [ShareParser] Found URL: \(url.absoluteString)")
                        safeCompletion(.success(SharedCandidate(sourceURL: url)))
                    } else if let str = item as? String, let url = URL(string: str) {
                        logger.info("Found URL from string: \(url.absoluteString)")
                        print("✅ [ShareParser] Found URL from string: \(url.absoluteString)")
                        safeCompletion(.success(SharedCandidate(sourceURL: url)))
                    } else {
                        print("⚠️ [ShareParser] URL provider returned unexpected type: \(type(of: item))")
                        next()
                    }
                }
            } else {
                next()
            }
        }
        
        func tryText(_ provider: NSItemProvider, _ next: @escaping () -> Void) {
            if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                logger.info("Provider has plain text type")
                provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { item, error in
                    if let error = error {
                        logger.error("Error loading text: \(error.localizedDescription)")
                        next()
                        return
                    }
                    let text = (item as? String) ?? (item as? Data).flatMap { String(data: $0, encoding: .utf8) }
                    if let text, let url = detectFirstURL(in: text) {
                        logger.info("Found URL in text: \(url.absoluteString)")
                        safeCompletion(.success(SharedCandidate(sourceURL: url, rawText: text)))
                    } else if let text {
                        logger.info("Found plain text (no URL): \(text.prefix(50))...")
                        safeCompletion(.success(SharedCandidate(sourceURL: nil, rawText: text)))
                    } else {
                        next()
                    }
                }
            } else {
                next()
            }
        }
        
        func tryMovie(_ provider: NSItemProvider, _ next: @escaping () -> Void) {
            if provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
                logger.info("Provider has movie type")
                provider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { fileURL, error in
                    if let error = error {
                        logger.error("Error loading movie: \(error.localizedDescription)")
                        next()
                        return
                    }
                    if let fileURL {
                        logger.info("Found movie file: \(fileURL.lastPathComponent)")
                        safeCompletion(.success(SharedCandidate(sourceURL: nil, movieFileURL: fileURL)))
                    } else {
                        next()
                    }
                }
            } else {
                next()
            }
        }
        
        func tryImage(_ provider: NSItemProvider, _ next: @escaping () -> Void) {
            if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                logger.info("Provider has image type")
                provider.loadFileRepresentation(forTypeIdentifier: UTType.image.identifier) { fileURL, error in
                    if let error = error {
                        logger.error("Error loading image: \(error.localizedDescription)")
                        next()
                        return
                    }
                    if let fileURL {
                        logger.info("Found image file: \(fileURL.lastPathComponent)")
                        safeCompletion(.success(SharedCandidate(sourceURL: nil, imageFileURL: fileURL)))
                    } else {
                        next()
                    }
                }
            } else {
                next()
            }
        }
        
        // Iterate providers and try in order: URL -> Text -> Movie -> Image
        var idx = 0
        func processNextProvider() {
            guard idx < providers.count else {
                logger.error("No supported payload found in any provider")
                safeCompletion(.failure(ShareParserError.noSupportedPayload))
                return
            }
            let p = providers[idx]
            logger.info("Processing provider \(idx + 1)/\(providers.count)")
            idx += 1
            
            // Also check for text identifier as fallback
            let hasText = p.hasItemConformingToTypeIdentifier(UTType.text.identifier)
            let hasPlainText = p.hasItemConformingToTypeIdentifier(UTType.plainText.identifier)
            
            tryURL(p) {
                if hasPlainText {
                    tryText(p) {
                        tryMovie(p) {
                            tryImage(p) {
                                processNextProvider()
                            }
                        }
                    }
                } else if hasText {
                    // Try regular text as fallback
                    p.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { item, _ in
                        let text = (item as? String) ?? (item as? Data).flatMap { String(data: $0, encoding: .utf8) }
                        if let text, let url = detectFirstURL(in: text) {
                            logger.info("Found URL in text (via UTType.text): \(url.absoluteString)")
                            safeCompletion(.success(SharedCandidate(sourceURL: url, rawText: text)))
                        } else if let text {
                            logger.info("Found text (via UTType.text, no URL): \(text.prefix(50))...")
                            safeCompletion(.success(SharedCandidate(sourceURL: nil, rawText: text)))
                        } else {
                            tryMovie(p) {
                                tryImage(p) {
                                    processNextProvider()
                                }
                            }
                        }
                    }
                } else {
                    tryMovie(p) {
                        tryImage(p) {
                            processNextProvider()
                        }
                    }
                }
            }
        }
        
        processNextProvider()
    }
    
    private static func detectFirstURL(in text: String) -> URL? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let match = detector?.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text))
        if let r = match?.range, let swiftRange = Range(r, in: text) {
            return URL(string: String(text[swiftRange]))
        }
        return nil
    }
}

