import SwiftUI
import PadelKit

struct SettingsView: View {
    @AppStorage("defaultGoldenPoint") private var defaultGoldenPoint = false
    @AppStorage("defaultSetsToWin") private var defaultSetsToWin = 2
    @AppStorage("defaultAmericanoPoints") private var defaultAmericanoPoints = 21
    @EnvironmentObject private var connectivity: PhoneConnectivityManager

    var body: some View {
        Form {
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
