import UIKit
import SwiftUI
import UniformTypeIdentifiers
import OSLog

final class ShareViewController: UIViewController {
    private let log = Logger(subsystem: "com.tamaraosseiran.clipboard.share", category: "Share")
    
    override func viewDidLoad() {
        super.viewDidLoad()
        log.info("Share extension launched.")
        
        let vc = UIHostingController(rootView: ShareRootView(context: self.extensionContext, logger: log))
        addChild(vc)
        vc.view.frame = view.bounds
        vc.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(vc.view)
        vc.didMove(toParent: self)
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
                .onAppear { parse() }
                
            case .filled:
                NavigationView {
                    Form {
                        Section(header: Text("Details")) {
                            TextField("Name", text: Binding($draft.name, default: ""))
                            TextField("Address", text: Binding($draft.address, default: ""))
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

private extension Binding where Value == String? {
    init(_ source: Binding<String?>, default defaultValue: String) {
        self.init(
            get: { source.wrappedValue ?? defaultValue },
            set: { source.wrappedValue = $0.isEmpty ? nil : $0 }
        )
    }
}

