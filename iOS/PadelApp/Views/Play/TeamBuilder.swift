import SwiftUI
import PadelKit

/// A single player slot: tap an empty one to target it, drag a player onto it,
/// or remove the occupant. Reused by the match court and the Mix pair builder.
struct PlayerSlotView: View {
    let player: Player?
    var accent: Color
    var isSelected: Bool = false
    var minHeight: CGFloat = 54
    var onTapEmpty: () -> Void = {}
    var onRemove: () -> Void = {}
    var onDrop: (String) -> Bool = { _ in false }

    var body: some View {
        content
            .dropDestination(for: String.self) { items, _ in
                guard let id = items.first else { return false }
                return onDrop(id)
            }
    }

    @ViewBuilder
    private var content: some View {
        if let player {
            HStack(spacing: 8) {
                PlayerAvatar(player: player, size: 30)
                Text(player.name)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .leading)
            .background(accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(accent.opacity(0.35), lineWidth: 1)
            )
            // An explicit preview lifts just this player — without it a slot
            // inside a Form drags a snapshot of the whole row.
            .draggable(player.id.uuidString) {
                HStack(spacing: 8) {
                    PlayerAvatar(player: player, size: 30)
                    Text(player.name)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        } else {
            VStack(spacing: 3) {
                Image(systemName: "plus")
                    .font(.headline)
                Text("Add")
                    .font(.caption)
            }
            .foregroundStyle(isSelected ? accent : Color.secondary)
            .frame(maxWidth: .infinity, minHeight: minHeight)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? accent.opacity(0.12) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        isSelected ? accent : Color.secondary.opacity(0.4),
                        style: StrokeStyle(lineWidth: 1.5, dash: [5])
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .onTapGesture(perform: onTapEmpty)
        }
    }
}

/// A visual court where a match's two teams' four slots are filled by tapping
/// or dragging players. Because a player occupies a single slot — and assigned
/// players drop out of the pool — the same person can never be picked twice.
struct TeamBuilder: View {
    /// The four slots: index 0/1 = Team A, index 2/3 = Team B.
    @Binding var slots: [Player?]
    /// The slot a tapped pool player fills, or `nil` to fill the first empty one.
    @Binding var selectedSlot: Int?
    /// Resolves a pool drag by id so it can be dropped into `target`.
    var onDropFromPool: (String, Int) -> Bool

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
        PlayerSlotView(
            player: slots[index],
            accent: PadelTheme.teamColor(side),
            isSelected: selectedSlot == index,
            onTapEmpty: {
                withAnimation(.snappy) {
                    selectedSlot = (selectedSlot == index) ? nil : index
                }
            },
            onRemove: {
                withAnimation(.snappy) {
                    slots[index] = nil
                    selectedSlot = index
                }
            },
            onDrop: { id in handleDrop(idString: id, into: index) }
        )
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
        return onDropFromPool(idString, target)
    }
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

/// A tappable, draggable player chip shown in the selection pool. An optional
/// trailing icon turns it into a removable "chosen player" chip.
struct PlayerChip: View {
    let player: Player
    var trailingSystemImage: String? = nil
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 7) {
                PlayerAvatar(player: player, size: 26)
                Text(player.name)
                    .font(.subheadline)
                    .lineLimit(1)
                if let trailingSystemImage {
                    Image(systemName: trailingSystemImage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(hex: player.colorHex).opacity(0.15), in: Capsule())
            .overlay(Capsule().stroke(Color(hex: player.colorHex).opacity(0.4), lineWidth: 1))
        }
        .buttonStyle(.plain)
        // An explicit preview lifts just this chip — without it a chip inside a
        // Form drags a snapshot of the whole row of players.
        .draggable(player.id.uuidString) {
            HStack(spacing: 7) {
                PlayerAvatar(player: player, size: 26)
                Text(player.name)
                    .font(.subheadline)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(hex: player.colorHex).opacity(0.15), in: Capsule())
        }
    }
}
