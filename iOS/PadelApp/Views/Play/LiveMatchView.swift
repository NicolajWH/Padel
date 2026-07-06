import SwiftUI
import SwiftData
import PadelKit

struct LiveMatchView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var connectivity: PhoneConnectivityManager
    let record: MatchRecord
    @State private var state: MatchState
    @State private var showingFinishedSheet = false
    @State private var showingShareSheet = false
    @StateObject private var share = SharedMatchController()
    @StateObject private var liveActivity = MatchLiveActivityController()
    @State private var suppressCloudPush = false

    init(record: MatchRecord, initialState: MatchState) {
        self.record = record
        self._state = State(initialValue: initialState)
    }

    var body: some View {
        let snap = state.snapshot

        ZStack {
            PadelTheme.scoreboardGradient
                .ignoresSafeArea()

            VStack(spacing: 0) {
                SetHistoryBar(sets: snap.completedSets)
                    .padding(.top, 12)

                HStack(spacing: 14) {
                    TeamScoreColumn(
                        team: state.teamA,
                        label: snap.gamePointLabelA,
                        games: snap.currentSetGamesA,
                        isServing: snap.servingSide == .teamA,
                        servingPlayerIndex: snap.servingPlayerIndex,
                        isTiebreak: snap.isTiebreak,
                        tiebreakPoints: snap.tiebreakPointsA,
                        color: PadelTheme.teamA
                    ) {
                        score(.teamA)
                    }

                    TeamScoreColumn(
                        team: state.teamB,
                        label: snap.gamePointLabelB,
                        games: snap.currentSetGamesB,
                        isServing: snap.servingSide == .teamB,
                        servingPlayerIndex: snap.servingPlayerIndex,
                        isTiebreak: snap.isTiebreak,
                        tiebreakPoints: snap.tiebreakPointsB,
                        color: PadelTheme.teamB
                    ) {
                        score(.teamB)
                    }
                }
                .padding()

                Spacer(minLength: 0)

                bottomBar
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(PadelTheme.courtDeep, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingShareSheet = true
                } label: {
                    Image(systemName: share.isSharing ? "person.2.wave.2.fill" : "square.and.arrow.up")
                }
                .tint(PadelTheme.lime)
            }
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: state.pointLog)
        .sensoryFeedback(.success, trigger: showingFinishedSheet)
        .onChange(of: state.pointLog) { _, _ in
            record.update(with: state)
            connectivity.send(.match(state))
            liveActivity.update(with: state)
            if share.isSharing {
                if suppressCloudPush {
                    suppressCloudPush = false
                } else {
                    let current = state
                    Task { await share.pushMatch(current) }
                }
            }
        }
        .onAppear {
            share.attach(id: state.id)
            connectivity.send(.match(state))
            liveActivity.start(for: state)
        }
        .onDisappear {
            share.detach()
            liveActivity.end(with: state)
        }
        .onChange(of: connectivity.lastReceivedMatch) { _, incoming in
            guard let incoming, incoming.id == state.id, incoming != state else { return }
            withAnimation(.snappy) { state = incoming }
        }
        .onChange(of: share.remoteMatch) { _, incoming in
            guard let incoming, incoming.id == state.id, incoming.pointLog != state.pointLog else { return }
            suppressCloudPush = true
            withAnimation(.snappy) { state = incoming }
        }
        .onChange(of: snap.isMatchOver) { _, isOver in
            if isOver {
                connectivity.send(.matchFinished(state))
                liveActivity.end(with: state)
                showingFinishedSheet = true
            }
        }
        .sheet(isPresented: $showingFinishedSheet) {
            MatchSummaryView(state: state)
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareMatchSheet(share: share, state: state)
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

    private var title: String {
        let snap = state.snapshot
        if snap.isMatchTiebreak { return String(localized: "Match Tiebreak") }
        if snap.isTiebreak { return String(localized: "Tiebreak") }
        return String(localized: "Live Match")
    }

    private var bottomBar: some View {
        HStack {
            Button {
                undo()
            } label: {
                Label("Undo", systemImage: "arrow.uturn.backward")
                    .font(.subheadline.weight(.semibold))
            }
            .tint(PadelTheme.lime)
            .disabled(state.pointLog.isEmpty)

            Spacer()

            if let code = share.shareCode {
                Label(code, systemImage: "person.2.wave.2.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PadelTheme.lime)
            }

            if connectivity.isWatchAppInstalled {
                Image(systemName: "applewatch")
                    .font(.caption)
                    .foregroundStyle(connectivity.isWatchReachable ? PadelTheme.lime : .white.opacity(0.35))
                    .padding(.leading, 8)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }

    private func score(_ side: TeamSide) {
        guard !state.snapshot.isMatchOver else { return }
        withAnimation(.snappy) { state.addPoint(for: side) }
    }

    private func undo() {
        withAnimation(.snappy) { state.undoLastPoint() }
    }
}

private struct TeamScoreColumn: View {
    let team: Team
    let label: String
    let games: Int
    let isServing: Bool
    let servingPlayerIndex: Int
    let isTiebreak: Bool
    let tiebreakPoints: Int
    let color: Color
    let onScore: () -> Void

    var body: some View {
        Button(action: onScore) {
            VStack(spacing: 14) {
                VStack(spacing: 3) {
                    ForEach(Array(team.players.enumerated()), id: \.element.id) { index, player in
                        HStack(spacing: 6) {
                            if isServing && index == servingPlayerIndex {
                                Image(systemName: "tennisball.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(PadelTheme.lime)
                            }
                            Text(player.name)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                    }
                }

                Text(isTiebreak ? "\(tiebreakPoints)" : label)
                    .font(.system(size: 64, weight: .heavy, design: .rounded))
                    .foregroundStyle(color)
                    .contentTransition(.numericText())
                    .minimumScaleFactor(0.5)
                    .shadow(color: color.opacity(0.55), radius: 14)

                Text("Games: \(games)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.65))
                    .contentTransition(.numericText())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(color.opacity(0.14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .strokeBorder(color.opacity(isServing ? 0.65 : 0.25), lineWidth: isServing ? 2 : 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

private struct SetHistoryBar: View {
    let sets: [SetScore]

    var body: some View {
        if !sets.isEmpty {
            HStack(spacing: 10) {
                ForEach(Array(sets.enumerated()), id: \.offset) { _, set in
                    Text("\(set.teamAGames)-\(set.teamBGames)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(.white.opacity(0.12))
                        .clipShape(Capsule())
                }
            }
        }
    }
}

/// Sheet that publishes the match under a court number and the phone's
/// location, so everyone nearby can join with one tap. The join code is
/// shown afterwards as a fallback for when location isn't available.
private struct ShareMatchSheet: View {
    @ObservedObject var share: SharedMatchController
    let state: MatchState
    @Environment(\.dismiss) private var dismiss
    @StateObject private var locationProvider = LocationProvider()
    @State private var court = 1

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "person.2.wave.2.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.accentColor)
                    .padding(.top, 8)

                if let code = share.shareCode {
                    Text("Sharing is on. Players nearby can now join this match from the Play tab.")
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

                    ShareLink(item: shareText(code: code)) {
                        Label("Share Code", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .padding(.horizontal)
                } else {
                    Text("Share this match so everyone on court can follow and update the score live from their own iPhone and Apple Watch.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    Picker("Court", selection: $court) {
                        ForEach(1...8, id: \.self) { number in
                            Text("Court \(number)").tag(number)
                        }
                    }
                    .pickerStyle(.menu)

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
                            await share.startSharingMatch(state, court: court, location: location)
                        }
                    } label: {
                        if share.isBusy {
                            ProgressView().frame(maxWidth: .infinity)
                        } else {
                            Label("Share Match", systemImage: "person.2.wave.2")
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
            .navigationTitle("Shared Match")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func shareText(code: String) -> String {
        String(localized: "Join my padel match in the Padel app with code \(code)")
    }
}

#Preview {
    let teamA = Team(players: [Player(name: "Alice"), Player(name: "Ana")])
    let teamB = Team(players: [Player(name: "Bea"), Player(name: "Bob")])
    let state = MatchState(teamA: teamA, teamB: teamB)
    let record = MatchRecord.create(from: state)
    return NavigationStack {
        LiveMatchView(record: record, initialState: state)
    }
    .environmentObject(PhoneConnectivityManager.shared)
    .modelContainer(for: [SavedPlayerRecord.self, MatchRecord.self, AmericanoRecord.self], inMemory: true)
}
