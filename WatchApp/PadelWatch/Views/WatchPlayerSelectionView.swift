import SwiftUI
import PadelKit

/// A compact, shared player picker for match and mix setup. Keeping selection
/// in one list makes it obvious who is already playing and prevents duplicates.
struct WatchPlayerSelectionView: View {
    let players: [Player]
    @Binding var selection: [UUID]
    let maximumSelection: Int

    var body: some View {
        List {
            Section {
                ForEach(players) { player in
                    Button {
                        toggle(player.id)
                    } label: {
                        HStack(spacing: 8) {
                            Text(player.initials)
                                .font(.headline.monospaced())
                                .frame(width: 34)
                            Text(player.name)
                                .font(.caption2)
                                .lineLimit(1)
                            Spacer()
                            if selection.contains(player.id) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(PadelTheme.lime)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(!selection.contains(player.id) && selection.count >= maximumSelection)
                }
            } header: {
                Text("Selected \(selection.count) of \(maximumSelection)")
            }
        }
        .navigationTitle("Players")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func toggle(_ id: UUID) {
        if let index = selection.firstIndex(of: id) {
            selection.remove(at: index)
        } else if selection.count < maximumSelection {
            selection.append(id)
        }
    }
}
