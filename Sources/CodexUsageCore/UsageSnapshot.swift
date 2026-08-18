import Foundation

public struct UsageSnapshot: Codable, Equatable, Sendable {
    public let remainingPercent: Int
    public let usedPercent: Int
    public let resetAt: Date?
    public let windowDurationMinutes: Int?
    public let fetchedAt: Date
    public let source: String
    public let planType: String?

    public init(
        remainingPercent: Int,
        usedPercent: Int,
        resetAt: Date?,
        windowDurationMinutes: Int?,
        fetchedAt: Date,
        source: String,
        planType: String?
    ) {
        self.remainingPercent = min(100, max(0, remainingPercent))
        self.usedPercent = min(100, max(0, usedPercent))
        self.resetAt = resetAt
        self.windowDurationMinutes = windowDurationMinutes
        self.fetchedAt = fetchedAt
        self.source = source
        self.planType = planType
    }

    public var isWeekly: Bool {
        guard let minutes = windowDurationMinutes else { return false }
        return abs(minutes - 10_080) <= 60
    }

    public func isStale(at date: Date = Date(), threshold: TimeInterval = 30 * 60) -> Bool {
        date.timeIntervalSince(fetchedAt) > threshold
    }
}

public enum UsageSnapshotStore {
    public static let appGroupIdentifier = "group.com.siqi.codexusagepeek"
    private static let snapshotKey = "codex.weekly-usage.snapshot.v1"

    public static func load() -> UsageSnapshot? {
        for defaults in candidateDefaults {
            guard let data = defaults.data(forKey: snapshotKey),
                  let snapshot = try? JSONDecoder().decode(UsageSnapshot.self, from: data)
            else { continue }
            return snapshot
        }
        return nil
    }

    public static func save(_ snapshot: UsageSnapshot) throws {
        let data = try JSONEncoder().encode(snapshot)
        for defaults in candidateDefaults {
            defaults.set(data, forKey: snapshotKey)
        }
    }

    private static var candidateDefaults: [UserDefaults] {
        var defaults = [UserDefaults.standard]
        if let groupDefaults = UserDefaults(suiteName: appGroupIdentifier) {
            defaults.insert(groupDefaults, at: 0)
        }
        return defaults
    }
}
