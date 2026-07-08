import SwiftUI
import PadelKit

/// A visual court where players are assigned to the four match slots by
/// tapping or dragging. Because a player can occupy only one slot at a time
/// — and assigned players drop out of the pool below — the same person can
/// never be picked twice.
struct TeamBuilder: View {
    /// The four slots: index 0/1 = Team A, index 2/3 = Team B.
    @Binding var slots: [Player?]
    /// The slot a tapped pool player fills, or `nil` to fill the first empty one.
    @Binding var selectedSlot: Int?

    var body: some View {
        VStack(spacing: 10) {
            teamRow(title: "Your Team", side: .teamA, indices: [0, 1])
            divider
            teamRow(title: "Their Team", side: .teamB, indices: [2, 3])
        }
    }

    private var divider: some View {
        HStack(spacing: 10) {
            line
            Text("VS")
                .font(.caption.weight(.heavy))
                .foregroundStyle(.secondary)
            line
        }
    }

    private var line: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.25))
            .frame(height: 1)
    }

    private func teamRow(title: LocalizedStringKey, side: TeamSide, indices: [Int]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Circle()
                    .fill(PadelTheme.teamColor(side))
                    .frame(width: 8, height: 8)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 10) {
                slotView(indices[0], side: side)
                slotView(indices[1], side: side)
            }
        }
    }

    private func slotView(_ index: Int, side: TeamSide) -> some View {
        let color = PadelTheme.teamColor(side)
        let isSelected = selectedSlot == index
        return Group {
            if let player = slots[index] {
                HStack(spacing: 8) {
                    PlayerAvatar(player: player, size: 30)
                    Text(player.name)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Spacer(minLength: 0)
                    Button {
                        withAnimation(.snappy) { clear(index) }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 10)
                .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
                .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(color.opacity(0.35), lineWidth: 1)
                )
                .draggable(player.id.uuidString)
            } else {
                VStack(spacing: 3) {
                    Image(systemName: "plus")
                        .font(.headline)
                    Text("Add")
                        .font(.caption)
                }
                .foregroundStyle(isSelected ? color : Color.secondary)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(isSelected ? color.opacity(0.12) : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(
                            isSelected ? color : Color.secondary.opacity(0.4),
                            style: StrokeStyle(lineWidth: 1.5, dash: [5])
                        )
                )
                .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .onTapGesture {
                    withAnimation(.snappy) {
                        selectedSlot = (selectedSlot == index) ? nil : index
                    }
                }
            }
        }
        .dropDestination(for: String.self) { items, _ in
            guard let idString = items.first else { return false }
            return handleDrop(idString: idString, into: index)
        }
    }

    private func clear(_ index: Int) {
        slots[index] = nil
        selectedSlot = index
    }

    /// Resolves a dragged player id and moves them into `target`, swapping
    /// with the source slot when the drag started from another slot.
    private func handleDrop(idString: String, into target: Int) -> Bool {
        if let source = slots.firstIndex(where: { $0?.id.uuidString == idString }) {
            guard source != target else { return false }
            withAnimation(.snappy) {
                let displaced = slots[target]
                slots[target] = slots[source]
                slots[source] = displaced
            }
            return true
        }
        // Dragged in from the pool — let the coordinator resolve the id.
        return onDropFromPool?(idString, target) ?? false
    }

    /// Set by the owner so pool drags can be resolved against its candidate list.
    var onDropFromPool: ((String, Int) -> Bool)?
}

/// A wrapping row of items — used for the tappable / draggable player pool.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, maxRowWidth: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            maxRowWidth = max(maxRowWidth, x - spacing)
        }
        return CGSize(width: min(maxWidth, maxRowWidth), height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            sub.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

/// A tappable, draggable player chip shown in the selection pool.
struct PlayerChip: View {
    let player: Player
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 7) {
                PlayerAvatar(player: player, size: 26)
                Text(player.name)
                    .font(.subheadline)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(hex: player.colorHex).opacity(0.15), in: Capsule())
            .overlay(Capsule().stroke(Color(hex: player.colorHex).opacity(0.4), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .draggable(player.id.uuidString)
    }
}
