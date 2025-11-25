import SwiftUI

struct SharePreviewData: Identifiable, Codable {
    let id: UUID = UUID()
    var urlString: String
    var title: String
    var description: String
    var address: String
    var contentType: String

    private enum CodingKeys: String, CodingKey {
        case urlString, title, description, address, contentType
    }
}

struct SharePreviewView: View {
    @Environment(\.dismiss) private var dismiss

    @State var data: SharePreviewData
    @State private var isSaving: Bool = false
    let onSave: (SharePreviewData) -> Void

    var body: some View {
        NavigationView {
            Form {
                Section("Source") {
                    TextField("URL", text: $data.urlString)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Section("Details") {
                    TextField("Title", text: $data.title)
                    TextField("Description", text: $data.description, axis: .vertical)
                    TextField("Address", text: $data.address)
                    Picker("Category", selection: $data.contentType) {
                        Text("Place").tag("place")
                        Text("Restaurant").tag("restaurant")
                        Text("Recipe").tag("recipe")
                        Text("Activity").tag("activity")
                        Text("Shop").tag("shop")
                        Text("Other").tag("other")
                    }
                    .pickerStyle(.navigationLink)
                }
            }
            .navigationTitle("Save to Spots")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isSaving ? "Saving…" : "Save") {
                        guard !isSaving else { return }
                        isSaving = true
                        onSave(data)
                    }
                    .disabled(isSaving)
                }
            }
        }
    }
}


