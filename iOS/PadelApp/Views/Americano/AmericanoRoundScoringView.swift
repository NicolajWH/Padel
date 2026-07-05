import SwiftUI
import UIKit
import PadelKit

struct AmericanoRoundScoringView: View {
    @EnvironmentObject private var connectivity: PhoneConnectivityManager
    let record: AmericanoRecord
    @State private var session: AmericanoSession
    @State private var roundIndex: Int
    @StateObject private var share = SharedMatchController()
    @State private var showingShareSheet = false
    @State private var suppressCloudPush = false

    init(record: AmericanoRecord, session: AmericanoSession) {
        self.record = record
        self._session = State(initialValue: session)
        self._roundIndex = State(initialValue: session.currentRoundIndex)
    }

    private var round: AmericanoRound? {
        guard session.rounds.indices.contains(roundIndex) else { return nil }
        return session.rounds[roundIndex]
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Picker("Round", selection: $roundIndex) {
                    ForEach(session.rounds.indices, id: \.self) { index in
                        Text("Round \(index + 1)").tag(index)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                if let round {
                    ForEach(round.matchups) { matchup in
                        MatchupCard(matchup: matchup, target: session.settings.pointsPerRound) { side in
                            addPoint(matchupID: matchup.id, side: side)
                        } onUndo: {
                            undo(matchupID: matchup.id)
                        }
                        .padding(.horizontal)
                    }
                }

                NavigationLink {
                    AmericanoStandingsView(record: record, session: session)
                } label: {
                    Label("View Standings", systemImage: "list.number")
                }
                .padding(.top, 8)
            }
            .padding(.vertical)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .sensoryFeedback(.impact(weight: .medium), trigger: session)
        .navigationTitle(session.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingShareSheet = true
                } label: {
                    Image(systemName: share.isSharing ? "person.2.wave.2.fill" : "square.and.arrow.up")
                }
            }
        }
        .onChange(of: session) { _, newValue in
            record.update(with: newValue)
            connectivity.send(.americano(newValue))
            if newValue.isComplete {
                connectivity.send(.americanoFinished(newValue))
            }
            if share.isSharing {
                if suppressCloudPush {
                    suppressCloudPush = false
                } else {
                    Task { await share.pushAmericano(newValue) }
                }
            }
        }
        .onAppear {
            share.attach(id: session.id)
            connectivity.send(.americano(session))
        }
        .onDisappear {
            share.detach()
        }
        .onChange(of: connectivity.lastReceivedAmericano) { _, incoming in
            guard let incoming, incoming.id == session.id, incoming != session else { return }
            session = incoming
        }
        .onChange(of: share.remoteAmericano) { _, incoming in
            guard let incoming, incoming.id == session.id, incoming != session else { return }
            suppressCloudPush = true
            session = incoming
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareAmericanoSheet(share: share, session: session)
                .presentationDetents([.medium])
        }
        .alert(
            Text("Sharing Failed"),
            isPresented: Binding(
                get: { share.errorMessage != nil },
                set: { if !$0 { share.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(share.errorMessage ?? "")
        }
    }

    private func addPoint(matchupID: UUID, side: TeamSide) {
        guard var round = round else { return }
        guard let matchupIndex = round.matchups.firstIndex(where: { $0.id == matchupID }) else { return }
        round.matchups[matchupIndex].addPoint(to: side, target: session.settings.pointsPerRound)
        session.rounds[roundIndex] = round
    }

    private func undo(matchupID: UUID) {
        guard var round = round else { return }
        guard let matchupIndex = round.matchups.firstIndex(where: { $0.id == matchupID }) else { return }
        round.matchups[matchupIndex].undoLastPoint()
        session.rounds[roundIndex] = round
    }
}

private struct MatchupCard: View {
    let matchup: AmericanoMatchup
    let target: Int
    let onScore: (TeamSide) -> Void
    let onUndo: () -> Void

    var body: some View {
        let score = matchup.score(target: target)
        VStack(spacing: 12) {
            Text("Court \(matchup.court)")
                .font(.caption).foregroundStyle(.secondary)

            HStack(spacing: 12) {
                TeamButton(team: matchup.teamA, points: score.a, disabled: score.isComplete, color: PadelTheme.teamA) {
                    onScore(.teamA)
                }
                TeamButton(team: matchup.teamB, points: score.b, disabled: score.isComplete, color: PadelTheme.teamB) {
                    onScore(.teamB)
                }
            }

            HStack {
                if score.isComplete {
                    Label("Finished", systemImage: "checkmark.circle.fill").foregroundStyle(.green).font(.caption)
                }
                Spacer()
                Button(action: onUndo) {
                    Label("Undo", systemImage: "arrow.uturn.backward")
                }
                .font(.caption)
                .disabled(matchup.pointLog.isEmpty)
            }
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

private struct TeamButton: View {
    let team: Team
    let points: Int
    let disabled: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(team.displayName)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                Text("\(points)")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
                    .contentTransition(.numericText())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(color.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }
}

/// Sheet that publishes the Americano session with the phone's location so
/// everyone at the venue can join with one tap and pick who they are.
struct ShareAmericanoSheet: View {
    @ObservedObject var share: SharedMatchController
    let session: AmericanoSession
    @Environment(\.dismiss) private var dismiss
    @StateObject private var locationProvider = LocationProvider()

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "person.3.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.accentColor)
                    .padding(.top, 8)

                if let code = share.shareCode {
                    Text("Sharing is on. Players nearby can now join this Americano, pick who they are, and score their own court.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    VStack(spacing: 4) {
                        Text("Match Code")
                            .font(.headline)
                        Text(code)
                            .font(.system(size: 40, weight: .heavy, design: .rounded))
                            .kerning(6)
                            .textSelection(.enabled)
                        Text("Only needed if automatic discovery can't find the match.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("Share this Americano so everyone at the venue can follow the standings and score their own court live.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    if locationProvider.isAuthorizationDenied {
                        Text("Location access is off, so nearby players will need the code to join. You can enable location for Padel in Settings.")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    Button {
                        Task {
                            let location = await locationProvider.currentLocation()
                            await share.startSharingAmericano(session, location: location)
                        }
                    } label: {
                        if share.isBusy {
                            ProgressView().frame(maxWidth: .infinity)
                        } else {
                            Label("Share Americano", systemImage: "person.2.wave.2")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(share.isBusy)
                    .padding(.horizontal)
                }

                Spacer()
            }
            .padding(.top)
            .navigationTitle("Shared Americano")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    let players = (1...4).map { Player(name: "P\($0)") }
    let settings = AmericanoSettings.standard(playerCount: 4)
    let rounds = AmericanoScheduler.generateSchedule(players: players, settings: settings)
    let session = AmericanoSession(players: players, settings: settings, rounds: rounds)
    let record = AmericanoRecord.create(from: session)
    return NavigationStack {
        AmericanoRoundScoringView(record: record, session: session)
    }
    .environmentObject(PhoneConnectivityManager.shared)
}
