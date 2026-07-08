import SwiftUI
import PadelKit

struct WatchNewAmericanoView: View {
    @EnvironmentObject private var store: WatchStore
    @EnvironmentObject private var connectivity: WatchConnectivityManager
    @State private var playerCount = 4
    @State private var pointsPerRound = 21
    @State private var format: AmericanoFormat = .americano
    @State private var fixedPartners = false
    @State private var navigate = false
    /// Editable line-up. Defaults to P1…Pn so a session can start with a single
    /// tap, but every name can be dictated/scribbled so real players show up on
    /// the scoreboard and in the standings instead of anonymous placeholders.
    @State private var playerNames: [String] = (1...4).map { "P\($0)" }

    /// One court per four players — the same rule the phone uses. Shown so the
    /// setup reads as a plain summary instead of yet another dial to fiddle with.
    private var courtCount: Int { max(1, playerCount / 4) }

    var body: some View {
        Form {
            // Format first, as a plain segmented choice: the old toggle buried
            // "Mexicano" behind a parenthetical nobody reads on a tiny screen.
            Section {
                Picker("Format", selection: $format) {
                    ForEach(AmericanoFormat.allCases, id: \.self) { fmt in
                        Text(fmt.displayName).tag(fmt)
                    }
                }
                .font(.footnote)
                .pickerStyle(.navigationLink)
            }

            // Only the two knobs that actually change how it plays. Rounds and
            // courts are derived so setup is "pick players, pick points, start".
            Section {
                Stepper(value: $playerCount, in: 4...16, step: 4) {
                    Text("Players: \(playerCount)").font(.footnote)
                }
                Stepper(value: $pointsPerRound, in: 8...40, step: 1) {
                    Text("Points/round: \(pointsPerRound)").font(.footnote)
                }
                Toggle(isOn: $fixedPartners) {
                    Text("Fixed partners").font(.footnote)
                }
            } footer: {
                Text(summary).font(.caption2)
            }

            // Names live behind a link so the setup stays short: tap to open a
            // list where each player can be renamed by scribble or dictation.
            Section {
                NavigationLink {
                    WatchMixPlayersView(names: $playerNames)
                } label: {
                    HStack {
                        Text("Players").font(.footnote)
                        Spacer()
                        Text(playerNames.prefix(2).joined(separator: ", ") + (playerCount > 2 ? "…" : ""))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Section {
                Button {
                    start()
                } label: {
                    Text("Start")
                        .font(.footnote.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .tint(PadelTheme.lime)
            }
        }
        .navigationTitle("Mix")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: playerCount) { _, count in
            resizePlayerNames(to: count)
        }
        .navigationDestination(isPresented: $navigate) {
            WatchAmericanoRoundView()
        }
    }

    private var summary: String {
        let rounds = AmericanoSettings.standard(playerCount: playerCount).numberOfRounds
        let courtsText = courtCount == 1
            ? String(localized: "1 court")
            : String(localized: "\(courtCount) courts")
        let roundsText = String(localized: "\(rounds) rounds")
        return "\(courtsText) · \(roundsText)"
    }

    /// Keeps the editable name list the same length as the player count,
    /// preserving anything already typed and back-filling new slots with Pn.
    private func resizePlayerNames(to count: Int) {
        if playerNames.count < count {
            playerNames.append(contentsOf: (playerNames.count + 1...count).map { "P\($0)" })
        } else if playerNames.count > count {
            playerNames.removeLast(playerNames.count - count)
        }
    }

    private func start() {
        let players = playerNames.enumerated().map { index, name -> Player in
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            return Player(name: trimmed.isEmpty ? "P\(index + 1)" : trimmed)
        }
        // Derive rounds/courts from the shared default so the watch matches the
        // phone; only the two hand-picked values (points, format) override it.
        var settings = AmericanoSettings.standard(playerCount: playerCount)
        settings.pointsPerRound = pointsPerRound
        settings.format = format
        settings.fixedPartners = fixedPartners
        let rounds = AmericanoScheduler.generateSchedule(players: players, settings: settings)
        let session = AmericanoSession(name: format.displayName, players: players, settings: settings, rounds: rounds)
        store.activeAmericano = session
        connectivity.send(.americano(session))
        navigate = true
    }
}

/// A tiny name editor: one scribble/dictation field per player. Kept trivial on
/// purpose — the watch is for quick tweaks, full roster management is on iPhone.
struct WatchMixPlayersView: View {
    @Binding var names: [String]

    var body: some View {
        List {
            ForEach(names.indices, id: \.self) { index in
                TextField("Player \(index + 1)", text: $names[index])
                    .font(.footnote)
            }
        }
        .navigationTitle("Players")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { WatchNewAmericanoView() }
        .environmentObject(WatchStore.shared)
        .environmentObject(WatchConnectivityManager.shared)
}
