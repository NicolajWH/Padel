import Foundation
import WatchConnectivity
import PadelKit

@MainActor
final class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()

    @Published var isPhoneReachable: Bool = false
    @Published var lastReceivedMatch: MatchState?
    @Published var lastReceivedAmericano: AmericanoSession?

    private var session: WCSession?

    /// The last payload that couldn't be delivered live because the phone was
    /// out of range. Application context gets it across eventually, but it can
    /// lag — so when reachability returns we push it as a message right away.
    private var pendingCatchUp: [String: Any]?

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
            pendingCatchUp = nil
            session.sendMessage(dict, replyHandler: nil) { [weak self] _ in
                self?.updateContext(dict)
            }
        } else {
            pendingCatchUp = dict
            updateContext(dict)
        }
    }

    private func flushPendingCatchUp() {
        guard let session, session.isReachable, let dict = pendingCatchUp else { return }
        pendingCatchUp = nil
        session.sendMessage(dict, replyHandler: nil, errorHandler: nil)
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
                WatchStore.shared.adoptIncomingMatch(state)
            case .americano(let session), .americanoFinished(let session):
                self.lastReceivedAmericano = session
                WatchStore.shared.adoptIncomingAmericano(session)
            case .clearActiveSession:
                WatchStore.shared.clearActiveSessions()
            case .requestLatest:
                break
            }
        }
    }
}

extension WatchConnectivityManager: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: (any Error)?) {
        Task { @MainActor in
            self.isPhoneReachable = session.isReachable
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable = session.isReachable
        Task { @MainActor in
            self.isPhoneReachable = reachable
            if reachable {
                self.flushPendingCatchUp()
            }
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
