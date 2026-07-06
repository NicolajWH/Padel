import ActivityKit
import Foundation
import PadelKit

/// Owns the Live Activity for one match: lock-screen / Dynamic Island score
/// while LiveMatchView is on screen. Failure-tolerant by design — if Live
/// Activities are disabled or a request fails, scoring is unaffected.
@MainActor
final class MatchLiveActivityController: ObservableObject {
    private var activity: Activity<MatchActivityAttributes>?

    func start(for state: MatchState) {
        guard !state.isFinished, activity == nil else { return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        // Returning to a match whose activity is still on the lock screen
        // (e.g. after navigating away and back) adopts it instead of stacking
        // a duplicate.
        if let existing = Activity<MatchActivityAttributes>.activities.first(where: { $0.attributes.matchID == state.id }) {
            activity = existing
            update(with: state)
            return
        }

        let attributes = MatchActivityAttributes(
            matchID: state.id,
            teamAName: state.teamA.displayName,
            teamBName: state.teamB.displayName
        )
        activity = try? Activity.request(
            attributes: attributes,
            content: .init(state: contentState(for: state), staleDate: nil)
        )
    }

    func update(with state: MatchState) {
        guard let activity else { return }
        let content = ActivityContent(state: contentState(for: state), staleDate: nil)
        Task { await activity.update(content) }
    }

    /// Ends the activity. A finished match lingers on the lock screen for a
    /// few minutes so the result can be seen; an abandoned one disappears.
    func end(with state: MatchState) {
        guard let activity else { return }
        self.activity = nil
        let content = ActivityContent(state: contentState(for: state), staleDate: nil)
        let policy: ActivityUIDismissalPolicy = state.isFinished ? .after(.now + 10 * 60) : .immediate
        Task { await activity.end(content, dismissalPolicy: policy) }
    }

    private func contentState(for state: MatchState) -> MatchActivityAttributes.ContentState {
        let snap = state.snapshot
        let winnerText: String
        if let winner = snap.winner {
            winnerText = "\(state.team(winner).displayName) wins"
        } else {
            winnerText = ""
        }
        return MatchActivityAttributes.ContentState(
            pointsA: snap.isTiebreak ? "\(snap.tiebreakPointsA)" : snap.gamePointLabelA,
            pointsB: snap.isTiebreak ? "\(snap.tiebreakPointsB)" : snap.gamePointLabelB,
            gamesA: snap.currentSetGamesA,
            gamesB: snap.currentSetGamesB,
            setsA: snap.setsWonA,
            setsB: snap.setsWonB,
            showSets: state.settings.setsToWin > 1,
            teamAServing: snap.servingSide == .teamA,
            isTiebreak: snap.isTiebreak,
            isFinished: snap.isMatchOver,
            statusText: winnerText
        )
    }
}
