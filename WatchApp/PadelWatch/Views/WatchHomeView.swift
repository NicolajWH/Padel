import SwiftUI
import PadelKit

struct WatchHomeView: View {
    @EnvironmentObject private var store: WatchStore
    @EnvironmentObject private var connectivity: WatchConnectivityManager

    var body: some View {
        List {
            if let match = store.activeMatch, !match.isFinished {
                Section {
                    NavigationLink {
                        WatchLiveMatchView()
                    } label: {
                        VStack(alignment: .leading) {
                            Text("Continue Match").font(.headline)
                            Text("\(match.teamA.displayName) vs \(match.teamB.displayName)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if let session = store.activeAmericano, !session.isComplete, !session.rounds.isEmpty {
                Section {
                    NavigationLink {
                        WatchAmericanoRoundView()
                    } label: {
                        VStack(alignment: .leading) {
                            Text("Continue Americano").font(.headline)
                            Text(session.name).font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section {
                NavigationLink("New Match") {
                    WatchNewMatchView()
                }
                NavigationLink("New Americano") {
                    WatchNewAmericanoView()
                }
            }

            Section {
                HStack {
                    Image(systemName: connectivity.isPhoneReachable ? "iphone.gen3" : "iphone.slash")
                    Text(connectivity.isPhoneReachable ? "iPhone Connected" : "iPhone Offline")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Padel")
    }
}

#Preview {
    NavigationStack { WatchHomeView() }
        .environmentObject(WatchStore.shared)
        .environmentObject(WatchConnectivityManager.shared)
}
