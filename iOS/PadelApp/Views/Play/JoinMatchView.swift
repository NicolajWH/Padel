import SwiftUI
import UIKit
import SwiftData
import CoreLocation
import PadelKit

/// Finds shared matches on courts near the user's location so they can join
/// with one tap — "Court 1" or "Court 2" — no code typing. Entering a code
/// manually remains available as a fallback for when location is off or the
/// GPS fix is poor indoors.
struct JoinMatchView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @StateObject private var locationProvider = LocationProvider()

    @State private var nearbyMatches: [NearbySharedMatch] = []
    @State private var isSearching = true
    @State private var searchFailed = false
    @State private var showingCodeEntry = false
    @State private var code = ""
    @State private var isJoining = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if isSearching {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("Searching for matches nearby…")
                                .foregroundStyle(.secondary)
                        }
                    } else if nearbyMatches.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            if locationProvider.isAuthorizationDenied {
                                Text("Location access is needed to find matches near you. Enable it for Padel in Settings, or join with a code below.")
                            } else if searchFailed {
                                Text("Couldn't search for matches nearby. Check your internet connection and try again.")
                            } else {
                                Text("No matches found nearby. Ask the player keeping score to turn on sharing in the live match.")
                            }
                        }
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    } else {
                        ForEach(nearbyMatches) { match in
                            Button {
                                join(state: match.state)
                            } label: {
                                NearbyMatchRow(match: match)
                            }
                            .buttonStyle(.plain)
                            .disabled(isJoining)
                        }
                    }
                } header: {
                    Text("Nearby Matches")
                } footer: {
                    if let errorMessage {
                        Text(errorMessage).foregroundStyle(.red)
                    }
                }

                Section {
                    if showingCodeEntry {
                        TextField("Match Code", text: $code)
                            .font(.system(.title3, design: .rounded).bold())
                            .kerning(2)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                        Button {
                            joinWithCode()
                        } label: {
                            if isJoining {
                                ProgressView()
                            } else {
                                Text("Join Match")
                            }
                        }
                        .disabled(isJoining || SharedMatchController.normalize(code).count < 4)
                    } else {
                        Button("Enter code manually") {
                            showingCodeEntry = true
                        }
                        .font(.footnote)
                    }
                }
            }
            .navigationTitle("Join Match")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await search() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(isSearching)
                }
            }
            .task {
                await search()
            }
        }
    }

    private func search() async {
        isSearching = true
        searchFailed = false
        errorMessage = nil
        defer { isSearching = false }

        guard let location = await locationProvider.currentLocation() else {
            nearbyMatches = []
            return
        }
        do {
            nearbyMatches = try await SharedMatchController.fetchNearbyMatches(around: location)
        } catch {
            nearbyMatches = []
            searchFailed = true
        }
    }

    private func joinWithCode() {
        let normalized = SharedMatchController.normalize(code)
        isJoining = true
        errorMessage = nil
        Task {
            do {
                let state = try await SharedMatchController.fetchSharedMatch(code: normalized)
                upsert(state)
                dismiss()
            } catch {
                errorMessage = SharedMatchController.friendlyMessage(for: error)
            }
            isJoining = false
        }
    }

    private func join(state: MatchState) {
        isJoining = true
        upsert(state)
        dismiss()
    }

    private func upsert(_ state: MatchState) {
        let matchID = state.id
        let descriptor = FetchDescriptor<MatchRecord>(predicate: #Predicate { $0.id == matchID })
        if let existing = try? modelContext.fetch(descriptor).first {
            existing.update(with: state)
        } else {
            modelContext.insert(MatchRecord.create(from: state))
        }
    }
}

private struct NearbyMatchRow: View {
    let match: NearbySharedMatch

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "sportscourt.fill")
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 36, height: 36)
                .background(Color.accentColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text("Court \(match.court)")
                    .font(.headline)
                Text("\(match.state.teamA.displayName) vs \(match.state.teamB.displayName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            let snap = match.state.snapshot
            Text("Sets \(snap.setsWonA)-\(snap.setsWonB)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
    }
}

#Preview {
    JoinMatchView()
        .modelContainer(for: [SavedPlayerRecord.self, MatchRecord.self, AmericanoRecord.self], inMemory: true)
}
