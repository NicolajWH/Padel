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
                        HStack(spacing: 8) {
                            Image(systemName: "play.circle.fill")
                                .foregroundStyle(PadelTheme.lime)
                                .font(.title3)
                            VStack(alignment: .leading) {
                                Text("Continue Match").font(.headline)
                                Text("\(match.teamA.displayName) vs \(match.teamB.displayName)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .listItemTint(PadelTheme.courtDeep)
                }
            }

            if let session = store.activeAmericano, !session.isComplete, !session.rounds.isEmpty {
                Section {
                    NavigationLink {
                        WatchAmericanoRoundView()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "person.3.fill")
                                .foregroundStyle(PadelTheme.lime)
                                .font(.caption)
                            VStack(alignment: .leading) {
                                Text("Continue Americano").font(.headline)
                                Text(session.name).font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .listItemTint(PadelTheme.courtDeep)
                }
            }

            Section {
                NavigationLink {
                    WatchNewMatchView()
                } label: {
                    Label {
                        Text("New Match")
                    } icon: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(PadelTheme.teamA)
                    }
                }
                NavigationLink {
                    WatchNewAmericanoView()
                } label: {
                    Label {
                        Text("New Americano")
                    } icon: {
                        Image(systemName: "person.3.fill")
                            .foregroundStyle(PadelTheme.teamB)
                    }
                }
            }

            Section {
                HStack {
                    Image(systemName: connectivity.isPhoneReachable ? "iphone.gen3" : "iphone.slash")
                    if connectivity.isPhoneReachable {
                        Text("iPhone Connected")
                    } else {
                        Text("iPhone Offline")
                    }
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
