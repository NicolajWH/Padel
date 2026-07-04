import SwiftUI
import UIKit
import SwiftData
import PadelKit

/// Lets the user enter a share code and pull a friend's live match down from
/// CloudKit. The joined match is stored locally and shows up as the ongoing
/// match on the Play tab, scoring straight into the shared record.
struct JoinMatchView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var code = ""
    @State private var isJoining = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "person.2.wave.2.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.accentColor)
                    .padding(.top, 24)

                Text("Enter the match code from the player who shared the match.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                TextField("Match Code", text: $code)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .kerning(4)
                    .multilineTextAlignment(.center)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .padding()
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.horizontal)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Button {
                    join()
                } label: {
                    if isJoining {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Label("Join Match", systemImage: "arrow.down.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isJoining || SharedMatchController.normalize(code).count < 4)
                .padding(.horizontal)

                Spacer()
            }
            .navigationTitle("Join Match")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func join() {
        let normalized = SharedMatchController.normalize(code)
        isJoining = true
        errorMessage = nil
        Task {
            do {
                let state = try await SharedMatchController.fetchSharedMatch(code: normalized)
                upsert(state)
                dismiss()
            } catch {
                errorMessage = SharedMatchController.friendlyMessage(for: error)
            }
            isJoining = false
        }
    }

    private func upsert(_ state: MatchState) {
        let matchID = state.id
        let descriptor = FetchDescriptor<MatchRecord>(predicate: #Predicate { $0.id == matchID })
        if let existing = try? modelContext.fetch(descriptor).first {
            existing.update(with: state)
        } else {
            modelContext.insert(MatchRecord.create(from: state))
        }
    }
}

#Preview {
    JoinMatchView()
        .modelContainer(for: [SavedPlayerRecord.self, MatchRecord.self, AmericanoRecord.self], inMemory: true)
}
