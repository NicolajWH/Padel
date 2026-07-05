import SwiftUI
import UIKit
import PadelKit

struct SettingsView: View {
    @AppStorage("defaultGoldenPoint") private var defaultGoldenPoint = false
    @AppStorage("defaultSetsToWin") private var defaultSetsToWin = 2
    @AppStorage("defaultAmericanoPoints") private var defaultAmericanoPoints = 21
    @AppStorage("profileName") private var profileName = ""
    @EnvironmentObject private var connectivity: PhoneConnectivityManager
    @Environment(\.openURL) private var openURL

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $profileName)
            } header: {
                Text("Your Name")
            } footer: {
                Text("Used to suggest who you are when you join a shared Americano.")
            }

            Section("Apple Watch") {
                HStack {
                    Text("Status")
                    Spacer()
                    if !connectivity.isWatchAppInstalled {
                        Text("Not Installed").foregroundStyle(.secondary)
                    } else if connectivity.isWatchReachable {
                        Text("Connected").foregroundStyle(.green)
                    } else {
                        Text("Not Reachable").foregroundStyle(.orange)
                    }
                }
            }

            Section {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                } label: {
                    HStack {
                        Label("Language", systemImage: "globe")
                        Spacer()
                        Image(systemName: "arrow.up.forward.app")
                            .foregroundStyle(.secondary)
                    }
                }
                .foregroundStyle(.primary)
            } footer: {
                Text("Padel follows your iPhone's language. To use a different language just for this app, change it in Settings. Your Apple Watch follows automatically.")
            }

            Section("Default Match Rules") {
                Toggle("Golden Point", isOn: $defaultGoldenPoint)
                Picker("Match Format", selection: $defaultSetsToWin) {
                    Text("Single Set").tag(1)
                    Text("Best of 3 Sets").tag(2)
                }
            }

            Section("Default Americano Rules") {
                Stepper("Points per round: \(defaultAmericanoPoints)", value: $defaultAmericanoPoints, in: 8...40)
            }

            Section("About") {
                LabeledContent("Version", value: appVersion)
                Text("Padel — score matches with real padel rules, run Americano tournaments, and play it all from your Apple Watch.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Settings")
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

#Preview {
    NavigationStack { SettingsView() }
        .environmentObject(PhoneConnectivityManager.shared)
}
