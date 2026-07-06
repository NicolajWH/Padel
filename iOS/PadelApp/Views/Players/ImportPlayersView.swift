import SwiftUI
import SwiftData
import PhotosUI
import PadelKit

/// Bulk-adds players by pasting a list of names, one per line — or by scanning
/// a screenshot of a friends list.
///
/// This is how you "import" a friends list from another app such as MATCHi:
/// there's no public MATCHi API to pull friends programmatically, so you either
/// paste the names you can see, or scan a screenshot of the list and let
/// on-device OCR pull the names out for you. Everything lands in the editable
/// list below to review first, and names that already exist as players are
/// detected and skipped so re-importing is safe.
struct ImportPlayersView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// Names of players that already exist, used to skip duplicates.
    let existingNames: [String]

    @State private var text = ""
    @State private var pickedItems: [PhotosPickerItem] = []
    @State private var isScanning = false

    private var existingKeys: Set<String> {
        Set(existingNames.map(PlayerKey.normalize))
    }

    /// One trimmed, non-empty name per line, de-duplicated within the paste.
    private var parsedNames: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for raw in text.split(whereSeparator: \.isNewline) {
            let name = raw.trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else { continue }
            if seen.insert(PlayerKey.normalize(name)).inserted {
                result.append(name)
            }
        }
        return result
    }

    /// Names that will actually be added (not already saved).
    private var newNames: [String] {
        parsedNames.filter { !existingKeys.contains(PlayerKey.normalize($0)) }
    }

    private var skippedCount: Int { parsedNames.count - newNames.count }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Paste names, one per line", text: $text, axis: .vertical)
                        .lineLimit(6...20)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()

                    PhotosPicker(selection: $pickedItems, maxSelectionCount: 8, matching: .images) {
                        Label("Scan screenshot", systemImage: "text.viewfinder")
                    }
                    .disabled(isScanning)

                    if isScanning {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Reading names…").foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Names")
                } footer: {
                    Text("Paste your friends list from another app (e.g. MATCHi) — one name per line — or scan a screenshot of the list and the names are read for you. Review them here before adding; names you already have are skipped.")
                }

                if !parsedNames.isEmpty {
                    Section("Will add \(newNames.count)") {
                        ForEach(newNames, id: \.self) { name in
                            Label(name, systemImage: "person.crop.circle.badge.plus")
                        }
                        if skippedCount > 0 {
                            Text("\(skippedCount) already added — skipped")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Import Players")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: pickedItems) { _, items in
                guard !items.isEmpty else { return }
                scan(items)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add \(newNames.count)") { importNames() }
                        .disabled(newNames.isEmpty)
                }
            }
        }
    }

    private func importNames() {
        for name in newNames {
            modelContext.insert(SavedPlayerRecord(name: name))
        }
        dismiss()
    }

    /// OCRs the picked screenshots and appends any names found to the editor.
    private func scan(_ items: [PhotosPickerItem]) {
        isScanning = true
        Task {
            var found: [String] = []
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    found.append(contentsOf: await ScreenshotNameScanner.names(from: data))
                }
            }
            await MainActor.run {
                append(found)
                pickedItems = []
                isScanning = false
            }
        }
    }

    /// Appends scanned names to the text editor, skipping ones already typed.
    private func append(_ names: [String]) {
        var seen = Set(
            text.split(whereSeparator: \.isNewline)
                .map { PlayerKey.normalize(String($0)) }
        )
        var additions: [String] = []
        for name in names where seen.insert(PlayerKey.normalize(name)).inserted {
            additions.append(name)
        }
        guard !additions.isEmpty else { return }
        let separator = text.isEmpty || text.hasSuffix("\n") ? "" : "\n"
        text += separator + additions.joined(separator: "\n")
    }
}

#Preview {
    ImportPlayersView(existingNames: ["Claus Hansen"])
        .modelContainer(for: [SavedPlayerRecord.self], inMemory: true)
}
