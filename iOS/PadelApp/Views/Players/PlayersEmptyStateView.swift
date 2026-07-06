import SwiftUI

/// The Players tab when nothing is saved yet. Instead of a bare "no players"
/// placeholder it uses the empty space to promote the screenshot import: a
/// short pitch, a numbered how-to for getting a friends screenshot out of
/// MATCHi, and a prominent button straight into the importer.
struct PlayersEmptyStateView: View {
    var onImport: () -> Void
    var onAddManually: () -> Void

    /// MATCHi on the Danish App Store.
    private let matchiURL = URL(string: "https://apps.apple.com/dk/app/matchi/id720782039?l=da")!

    private struct Step: Identifiable {
        let id: Int
        let title: String
        let icon: String
    }

    private let steps: [Step] = [
        Step(id: 1, title: "Open MATCHi", icon: "iphone"),
        Step(id: 2, title: "Go to Profile", icon: "person.crop.circle"),
        Step(id: 3, title: "Tap Friends", icon: "person.2"),
        Step(id: 4, title: "Take a screenshot", icon: "camera.viewfinder"),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                hero
                stepsCard
                actions
            }
            .padding(24)
            .frame(maxWidth: .infinity)
        }
    }

    private var hero: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.15))
                    .frame(width: 88, height: 88)
                Image(systemName: "text.viewfinder")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            }
            Text("Got MATCHi? Import your friends")
                .font(.title2.bold())
                .multilineTextAlignment(.center)
            Text("Take a screenshot of your friends list and import them as players — the names are read for you, no typing.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 16)
    }

    private var stepsCard: some View {
        VStack(spacing: 0) {
            ForEach(steps) { step in
                HStack(spacing: 14) {
                    Text("\(step.id)")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Color.accentColor))
                    Text(step.title)
                        .font(.body)
                    Spacer()
                    Image(systemName: step.icon)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 12)
                if step.id != steps.count {
                    Divider()
                }
            }
        }
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private var actions: some View {
        VStack(spacing: 12) {
            Button(action: onImport) {
                Label("Import from screenshot", systemImage: "square.and.arrow.down")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Link(destination: matchiURL) {
                Label("Get MATCHi in the App Store", systemImage: "arrow.up.right.square")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

            Button("Add players manually", action: onAddManually)
                .padding(.top, 4)
        }
    }
}

#Preview {
    NavigationStack {
        PlayersEmptyStateView(onImport: {}, onAddManually: {})
            .navigationTitle("Players")
    }
}
