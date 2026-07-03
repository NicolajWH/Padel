import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            NavigationStack { PlayHomeView() }
                .tabItem { Label("Play", systemImage: "tennis.racket") }

            NavigationStack { AmericanoHomeView() }
                .tabItem { Label("Americano", systemImage: "person.3.fill") }

            NavigationStack { HistoryView() }
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }

            NavigationStack { PlayersView() }
                .tabItem { Label("Players", systemImage: "person.crop.circle") }

            NavigationStack { SettingsView() }
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}

#Preview {
    RootTabView()
}
