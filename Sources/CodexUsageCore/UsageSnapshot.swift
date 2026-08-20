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

public enum CodexUsageWidgetIdentity {
    // Bump this when a previous WidgetKit timeline must be invalidated.
    public static let kind = "CodexUsageWidgetV3"
}

public enum UsageSnapshotStore {
    public static let appGroupIdentifier = "group.com.siqi.codexusagepeek"
    private static let snapshotKey = "codex.weekly-usage.snapshot.v1"
    private static let snapshotFilename = "CodexWeeklyUsageSnapshot.json"

    public static func load() -> UsageSnapshot? {
        // UserDefaults is eventually consistent across the app and Widget
        // processes. Prefer an atomically replaced file so a timeline reload
        // cannot race the preferences daemon and pick up the previous value.
        if let snapshotFileURL,
           let data = try? Data(contentsOf: snapshotFileURL),
           let snapshot = try? JSONDecoder().decode(UsageSnapshot.self, from: data) {
            return snapshot
        }

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

        if let snapshotFileURL {
            try data.write(to: snapshotFileURL, options: .atomic)
        }

        // Keep the preference copies for migration from older builds and for
        // the unsigned Card-only development build, which has no App Group.
        for defaults in candidateDefaults {
            defaults.set(data, forKey: snapshotKey)
        }
    }

    private static var snapshotFileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)?
            .appendingPathComponent(snapshotFilename, isDirectory: false)
    }

    private static var candidateDefaults: [UserDefaults] {
        var defaults = [UserDefaults.standard]
        if let groupDefaults = UserDefaults(suiteName: appGroupIdentifier) {
            defaults.insert(groupDefaults, at: 0)
        }
        return defaults
    }
}
