import Foundation
import WatchConnectivity
import PadelKit

@MainActor
final class PhoneConnectivityManager: NSObject, ObservableObject {
    static let shared = PhoneConnectivityManager()

    @Published var isWatchReachable: Bool = false
    @Published var isWatchAppInstalled: Bool = false
    @Published var lastReceivedMatch: MatchState?
    @Published var lastReceivedAmericano: AmericanoSession?

    private var session: WCSession?
    private var latestPlayerRoster: PlayerRoster?

    private override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
        self.session = session
    }

    func send(_ payload: SyncPayload) {
        guard let session, session.activationState == .activated else { return }
        let dict: [String: Any] = ["payload": payload.encoded()]
        if session.isReachable {
            session.sendMessage(dict, replyHandler: nil) { [weak self] _ in
                self?.updateContext(dict)
            }
        } else {
            updateContext(dict)
        }
    }

    func sendPlayerRoster(_ roster: PlayerRoster) {
        latestPlayerRoster = roster
        send(.playerRoster(roster))
    }

    private func updateContext(_ dict: [String: Any]) {
        guard let session else { return }
        try? session.updateApplicationContext(dict)
    }

    nonisolated private func handleIncoming(_ dict: [String: Any]) {
        guard let data = dict["payload"] as? Data, let payload = SyncPayload.decode(data) else { return }
        Task { @MainActor in
            switch payload {
            case .match(let state), .matchFinished(let state):
                self.lastReceivedMatch = state
            case .americano(let session), .americanoFinished(let session):
                self.lastReceivedAmericano = session
            case .requestLatest:
                if let roster = self.latestPlayerRoster { self.send(.playerRoster(roster)) }
            case .clearActiveSession, .playerRoster:
                break
            }
        }
    }
}

extension PhoneConnectivityManager: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: (any Error)?) {
        Task { @MainActor in
            self.isWatchAppInstalled = session.isWatchAppInstalled
            self.isWatchReachable = session.isReachable
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.isWatchReachable = session.isReachable
        }
    }

    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.isWatchAppInstalled = session.isWatchAppInstalled
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        handleIncoming(applicationContext)
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handleIncoming(message)
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        handleIncoming(userInfo)
    }
}
