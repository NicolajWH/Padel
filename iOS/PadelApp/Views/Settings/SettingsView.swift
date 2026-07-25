import SwiftUI
import UIKit
import PadelKit

struct SettingsView: View {
    @AppStorage("defaultGoldenPoint") private var defaultGoldenPoint = true
    @AppStorage("defaultSetsToWin") private var defaultSetsToWin = 1
    @AppStorage("defaultAmericanoPoints") private var defaultAmericanoPoints = 16
    @AppStorage("profileName") private var profileName = ""
    @AppStorage(AppAppearance.storageKey) private var appearance = AppAppearance.system
    @AppStorage(NearbyPlayersService.discoveryEnabledKey) private var nearbyDiscoveryEnabled = true
    @EnvironmentObject private var connectivity: PhoneConnectivityManager
    @StateObject private var healthSummary = HealthWorkoutSummaryStore()
    @Environment(\.openURL) private var openURL

    var body: some View {
        Form {
            Section {
                TextField("Your Name", text: $profileName)
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
                Text("Profile")
            } footer: {
                Text("Used to suggest who you are when you join a shared Americano. If this is empty, Padel fills it from your iPhone name in Settings when possible.")
            }

            Section("Appearance") {
                Picker("Appearance", selection: $appearance) {
                    ForEach(AppAppearance.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("Appearance")
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
                    if !connectivity.isWatchPaired {
                        Text(String(localized: "No Paired Watch", table: "Health"))
                            .foregroundStyle(.secondary)
                    } else if !connectivity.isWatchAppInstalled {
                        Text("Not Installed").foregroundStyle(.secondary)
                    } else if connectivity.isWatchReachable {
                        Text("Connected").foregroundStyle(.green)
                    } else {
                        Text(String(localized: "Installed", table: "Health"))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                if let summary = healthSummary.summary {
                    LabeledContent(String(localized: "Tennis workouts", table: "Health"), value: summary.workoutCount.formatted())
                    LabeledContent(String(localized: "Time played", table: "Health"), value: summary.formattedDuration)
                    LabeledContent(String(localized: "Active energy", table: "Health"), value: summary.formattedCalories)
                    LabeledContent(String(localized: "Average heart rate", table: "Health"), value: summary.formattedAverageHeartRate)
                    LabeledContent(String(localized: "Highest heart rate", table: "Health"), value: summary.formattedMaximumHeartRate)
                } else {
                    HStack {
                        if healthSummary.isLoading { ProgressView() }
                        Text(healthSummary.loadFailed ? "Health data unavailable" : String(localized: "Loading workouts…", table: "Health"))
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Apple Health")
            } footer: {
                Text(String(localized: "Tennis workouts from the last 30 days. Padel workouts appear as tennis because Health doesn't have a padel workout type yet. You can manage access under Health in your iPhone's Settings.", table: "Health"))
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

            Section {
                Toggle("Golden Point", isOn: $defaultGoldenPoint)
                Picker("Match Format", selection: $defaultSetsToWin) {
                    Text("Single Set").tag(1)
                    Text("Best of 3 Sets").tag(2)
                }
            } header: {
                Text("Default Match Rules")
            } footer: {
                Text("With Golden Point, 40–40 is decided by one final point. The receiving team chooses which side receives the serve, and the winner of the point wins the game.")
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
        .screenTitle("Settings")
        .tint(DesignSystem.accentLime)
        .task { await healthSummary.load() }
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
