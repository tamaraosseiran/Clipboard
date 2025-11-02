import UIKit
import SwiftUI
import UniformTypeIdentifiers
import OSLog

final class ShareViewController: UIViewController {
    private let log = Logger(subsystem: "com.tamaraosseiran.clipboard.share", category: "Share")
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("🔵 [ShareViewController] viewDidLoad called")
        log.info("Share extension launched.")
        
        // Set background color so we can see the view
        view.backgroundColor = .systemBackground
        
        // Create and add SwiftUI view immediately
        let rootView = ShareRootView(context: self.extensionContext, logger: log)
        let hostingController = UIHostingController(rootView: rootView)
        
        // Add as child view controller
        addChild(hostingController)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        hostingController.view.backgroundColor = .systemBackground
        view.addSubview(hostingController.view)
        
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        hostingController.didMove(toParent: self)
        
        print("🔵 [ShareViewController] SwiftUI view added, view frame: \(view.frame.debugDescription)")
        log.info("SwiftUI view added to ShareViewController")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        print("🔵 [ShareViewController] viewWillAppear called")
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        print("🔵 [ShareViewController] viewDidAppear called, frame: \(view.frame.debugDescription)")
        log.info("ShareViewController viewDidAppear called")
    }
}

struct ShareRootView: View {
    let context: NSExtensionContext?
    let logger: Logger
    
    @State private var uiState: UIState = .loading
    @State private var draft = ParsedSpotDraft.empty
    
    var body: some View {
        Group {
            switch uiState {
            case .loading:
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Reading content…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
                .onAppear {
                    print("🔵 [ShareRootView] Loading view appeared, starting parse")
                    logger.info("Loading view appeared, starting parse")
                    parse()
                }
                
            case .filled:
                NavigationView {
                    Form {
                        Section(header: Text("Details")) {
                            TextField("Name", text: Binding(
                                get: { draft.name ?? "" },
                                set: { draft.name = $0.isEmpty ? nil : $0 }
                            ))
                            TextField("Address", text: Binding(
                                get: { draft.address ?? "" },
                                set: { draft.address = $0.isEmpty ? nil : $0 }
                            ))
                            if let url = draft.sourceURL {
                                HStack {
                                    Text("Source")
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text(url.absoluteString)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                        .foregroundStyle(.secondary)
                                        .font(.footnote)
                                }
                            }
                        }
                        
                        if !draft.photos.isEmpty {
                            Section(header: Text("Preview")) {
                                ForEach(Array(draft.photos.enumerated()), id: \.offset) { index, photoURL in
                                    if photoURL.isFileURL {
                                        Text(photoURL.lastPathComponent)
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    } else {
                                        Text(photoURL.absoluteString)
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                    }
                                }
                            }
                        }
                        
                        Section {
                            HStack {
                                Button("Cancel") {
                                    complete(cancelled: true)
                                }
                                Spacer()
                                Button("Save") {
                                    saveAndComplete()
                                }
                                .bold()
                            }
                        }
                    }
                    .navigationTitle("Add to Spots")
                    .navigationBarTitleDisplayMode(.inline)
                }
                
            case .error(let message):
                VStack(spacing: 12) {
                    Text("Couldn't read that")
                        .font(.headline)
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    Button("Close") {
                        complete(cancelled: true)
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
            }
        }
    }
    
    private func parse() {
        guard let ctx = context else {
            uiState = .error("No extension context.")
            return
        }
        
        logger.info("Parsing input items…")
        ShareParser.parse(from: ctx, logger: logger) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let candidate):
                    self.logger.info("Parsing candidate built. Fetching metadata…")
                    MetadataFetcher.buildDraft(from: candidate, logger: self.logger) { draft in
                        DispatchQueue.main.async {
                            self.draft = draft
                            self.uiState = .filled
                        }
                    }
                    
                case .failure(let error):
                    self.logger.error("Parsing failed: \(error.localizedDescription)")
                    self.uiState = .error(error.localizedDescription)
                }
            }
        }
    }
    
    private func saveAndComplete() {
        do {
            try SharedStore().savePending(draft: draft)
            logger.info("Saved pending spot to App Group")
            complete(cancelled: false)
        } catch {
            logger.error("Save failed: \(error.localizedDescription)")
            uiState = .error("Couldn't save: \(error.localizedDescription)")
        }
    }
    
    private func complete(cancelled: Bool) {
        logger.info("Completing request (cancelled: \(cancelled))")
        context?.completeRequest(returningItems: nil)
    }
    
    enum UIState {
        case loading
        case filled
        case error(String)
    }
}

// Removed unused Binding extension

