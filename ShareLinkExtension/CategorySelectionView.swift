//
//  CategorySelectionView.swift
//  ShareLinkExtension
//
//  Category selection with option to create custom categories
//

import SwiftUI

struct CategorySelectionView: View {
    @Environment(\.dismiss) private var dismiss
    
    @Binding var selectedType: ContentType
    @Binding var customCategory: String
    var suggestedKeywords: [String]
    var confidence: EnrichedContent.CategoryConfidence
    
    @State private var isCreatingNew = false
    @State private var newCategoryName = ""
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        List {
            // Show suggestion info if available
            if confidence == .high && !suggestedKeywords.isEmpty {
                Section {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .foregroundColor(.blue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Suggested: \(selectedType.rawValue)")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("Based on: \(suggestedKeywords.prefix(3).joined(separator: ", "))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            
            // Predefined categories
            Section(header: Text("Categories")) {
                ForEach(ContentType.allCases, id: \.self) { type in
                    Button(action: {
                        selectedType = type
                        customCategory = ""  // Clear custom category when selecting predefined
                        dismiss()
                    }) {
                        HStack {
                            Text(type.icon)
                                .font(.title2)
                                .frame(width: 30)
                            Text(type.rawValue)
                                .foregroundColor(.primary)
                            Spacer()
                            if selectedType == type && customCategory.isEmpty {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                }
            }
            
            // Create new category section
            Section(header: Text("Custom Category")) {
                if isCreatingNew {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            TextField("Category name", text: $newCategoryName)
                                .textInputAutocapitalization(.words)
                                .focused($isTextFieldFocused)
                            
                            if !newCategoryName.isEmpty {
                                Button(action: {
                                    newCategoryName = ""
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        
                        HStack(spacing: 12) {
                            Button("Cancel") {
                                isCreatingNew = false
                                newCategoryName = ""
                            }
                            .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Button("Create") {
                                if !newCategoryName.trimmingCharacters(in: .whitespaces).isEmpty {
                                    customCategory = newCategoryName.trimmingCharacters(in: .whitespaces)
                                    selectedType = .other  // Use "other" as base type for custom
                                    dismiss()
                                }
                            }
                            .fontWeight(.semibold)
                            .disabled(newCategoryName.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }
                    .padding(.vertical, 4)
                } else {
                    Button(action: {
                        isCreatingNew = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            isTextFieldFocused = true
                        }
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.green)
                                .font(.title2)
                            Text("Create New Category")
                                .foregroundColor(.primary)
                            Spacer()
                        }
                    }
                }
                
                // Show current custom category if set
                if !customCategory.isEmpty && !isCreatingNew {
                    HStack {
                        Text("📌")
                            .font(.title2)
                            .frame(width: 30)
                        Text(customCategory)
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "checkmark")
                            .foregroundColor(.blue)
                            .fontWeight(.semibold)
                    }
                }
            }
        }
        .navigationTitle("Category")
        .navigationBarTitleDisplayMode(.inline)
    }
}
