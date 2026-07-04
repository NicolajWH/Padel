import Foundation
import SwiftData
import PadelKit

@Model
public final class SavedPlayerRecord {
    @Attribute(.unique) public var id: UUID
    public var name: String
    public var colorHex: String
    public var createdAt: Date

    public init(id: UUID = UUID(), name: String, colorHex: String = Player.randomColorHex(), createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.createdAt = createdAt
    }

    public var asPlayer: Player { Player(id: id, name: name, colorHex: colorHex) }
}

@Model
public final class MatchRecord {
    @Attribute(.unique) public var id: UUID
    public var createdAt: Date
    public var stateData: Data
    public var isFinished: Bool
    public var summary: String

    public init(id: UUID, createdAt: Date, stateData: Data, isFinished: Bool, summary: String) {
        self.id = id
        self.createdAt = createdAt
        self.stateData = stateData
        self.isFinished = isFinished
        self.summary = summary
    }

    public var state: MatchState? {
        try? JSONDecoder().decode(MatchState.self, from: stateData)
    }

    public func update(with state: MatchState) {
        self.stateData = (try? JSONEncoder().encode(state)) ?? stateData
        self.isFinished = state.isFinished
        let snap = state.snapshot
        self.summary = "\(state.teamA.displayName) vs \(state.teamB.displayName) · \(snap.setsWonA)-\(snap.setsWonB)"
    }

    public static func create(from state: MatchState) -> MatchRecord {
        let record = MatchRecord(id: state.id, createdAt: state.createdAt, stateData: Data(), isFinished: false, summary: "")
        record.update(with: state)
        return record
    }
}

@Model
public final class AmericanoRecord {
    @Attribute(.unique) public var id: UUID
    public var createdAt: Date
    public var sessionData: Data
    public var isFinished: Bool
    public var name: String

    public init(id: UUID, createdAt: Date, sessionData: Data, isFinished: Bool, name: String) {
        self.id = id
        self.createdAt = createdAt
        self.sessionData = sessionData
        self.isFinished = isFinished
        self.name = name
    }

    public var session: AmericanoSession? {
        try? JSONDecoder().decode(AmericanoSession.self, from: sessionData)
    }

    public func update(with session: AmericanoSession) {
        self.sessionData = (try? JSONEncoder().encode(session)) ?? sessionData
        self.isFinished = session.isComplete
        self.name = session.name
    }

    public static func create(from session: AmericanoSession) -> AmericanoRecord {
        let record = AmericanoRecord(id: session.id, createdAt: session.createdAt, sessionData: Data(), isFinished: false, name: session.name)
        record.update(with: session)
        return record
    }
}
