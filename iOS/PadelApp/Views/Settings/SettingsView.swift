import SwiftUI
import UIKit
import PadelKit

struct SettingsView: View {
    @AppStorage("defaultGoldenPoint") private var defaultGoldenPoint = false
    @AppStorage("defaultSetsToWin") private var defaultSetsToWin = 2
    @AppStorage("defaultAmericanoPoints") private var defaultAmericanoPoints = 21
    @AppStorage("profileName") private var profileName = ""
    @AppStorage(AppAppearance.storageKey) private var appearance = AppAppearance.system
    @AppStorage(NearbyPlayersService.discoveryEnabledKey) private var nearbyDiscoveryEnabled = true
    @EnvironmentObject private var connectivity: PhoneConnectivityManager
    @Environment(\.openURL) private var openURL

    var body: some View {
        Form {
            Section {
                TextField("Dit navn", text: $profileName)
                    .textContentType(.name)
                    .onAppear(perform: fillProfileNameFromIPhoneSettingsIfNeeded)

                if let suggestedName = iPhoneSettingsNameSuggestion, profileName != suggestedName {
                    Button {
                        profileName = suggestedName
                    } label: {
                        Label(
                            String(
                                format: NSLocalizedString(
                                    "Use %@",
                                    comment: "Button title for using a suggested iPhone settings name"
                                ),
                                suggestedName
                            ),
                            systemImage: "iphone"
                        )
                    }
                }
            } header: {
                Text("Profil")
            } footer: {
                Text("Used to suggest who you are when you join a shared Americano. If this is empty, Padel fills it from your iPhone name in Settings when possible.")
            }

            Section("Udseende") {
                Picker("Udseende", selection: $appearance) {
                    ForEach(AppAppearance.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("Udseende")
            }

            Section {
                Toggle("Visible to Players Nearby", isOn: $nearbyDiscoveryEnabled)
            } header: {
                Text("Players Nearby")
            } footer: {
                Text("When on, players at the same court can see your name and add you to a match or Americano with one tap. Your name and approximate location are shared through iCloud while you use the app.")
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
                HStack(spacing: 12) {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(.red)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Workouts on Apple Watch")
                        Text("Heart rate, calories, and duration")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Apple Health")
            } footer: {
                Text("When you keep score on your Apple Watch, Padel records the match as a workout in the Health app. It shows up as tennis — Health doesn't have a padel workout type yet. You can manage access under Health in your iPhone's Settings.")
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
                Text("Padel — score matches with real padel rules, run Americano and Mexicano tournaments, and play it all from your Apple Watch.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .screenTitle("Indstillinger")
        .onChange(of: nearbyDiscoveryEnabled) { _, enabled in
            if !enabled {
                Task { await NearbyPlayersService.unpublish() }
            }
        }
    }

    private var iPhoneSettingsNameSuggestion: String? {
        UserProfile.deviceNameSuggestion
    }

    private func fillProfileNameFromIPhoneSettingsIfNeeded() {
        guard profileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let suggestedName = iPhoneSettingsNameSuggestion
        else { return }

        profileName = suggestedName
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
