import Foundation

public enum CodexRateLimitParserError: LocalizedError, Equatable {
    case invalidResponse
    case serverError(String)
    case weeklyWindowMissing

    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Codex 返回了无法识别的数据。"
        case .serverError(let message):
            return "Codex 数据服务出错：\(message)"
        case .weeklyWindowMissing:
            return "Codex 没有返回一周用量窗口。"
        }
    }
}

public enum CodexRateLimitParser {
    public static func parseResponseLine(_ data: Data, fetchedAt: Date = Date()) throws -> UsageSnapshot {
        let envelope: RPCEnvelope
        do {
            envelope = try JSONDecoder().decode(RPCEnvelope.self, from: data)
        } catch {
            throw CodexRateLimitParserError.invalidResponse
        }

        if let error = envelope.error {
            throw CodexRateLimitParserError.serverError(error.message)
        }
        guard let result = envelope.result else {
            throw CodexRateLimitParserError.invalidResponse
        }

        let snapshots = orderedSnapshots(from: result)
        let candidates = snapshots.flatMap { snapshot -> [(RateLimitWindow, RateLimitSnapshot)] in
            [snapshot.primary, snapshot.secondary].compactMap { window in
                window.map { ($0, snapshot) }
            }
        }

        guard let selected = candidates.min(by: { lhs, rhs in
            weeklyDistance(lhs.0) < weeklyDistance(rhs.0)
        }), weeklyDistance(selected.0) <= 60 else {
            throw CodexRateLimitParserError.weeklyWindowMissing
        }

        let used = min(100, max(0, selected.0.usedPercent))
        let resetAt = selected.0.resetsAt.map { Date(timeIntervalSince1970: TimeInterval($0)) }
        return UsageSnapshot(
            remainingPercent: 100 - used,
            usedPercent: used,
            resetAt: resetAt,
            windowDurationMinutes: selected.0.windowDurationMins,
            fetchedAt: fetchedAt,
            source: "Codex App Server",
            planType: selected.1.planType
        )
    }

    private static func orderedSnapshots(from result: RateLimitResult) -> [RateLimitSnapshot] {
        var snapshots: [RateLimitSnapshot] = []
        if let codex = result.rateLimitsByLimitId?["codex"] {
            snapshots.append(codex)
        }
        snapshots.append(result.rateLimits)
        if let others = result.rateLimitsByLimitId {
            snapshots.append(contentsOf: others.sorted(by: { $0.key < $1.key }).map(\.value))
        }
        return snapshots
    }

    private static func weeklyDistance(_ window: RateLimitWindow) -> Int {
        guard let duration = window.windowDurationMins else { return .max }
        return abs(duration - 10_080)
    }
}

private struct RPCEnvelope: Decodable {
    let result: RateLimitResult?
    let error: RPCError?
}

private struct RPCError: Decodable {
    let message: String
}

private struct RateLimitResult: Decodable {
    let rateLimits: RateLimitSnapshot
    let rateLimitsByLimitId: [String: RateLimitSnapshot]?
}

private struct RateLimitSnapshot: Decodable {
    let primary: RateLimitWindow?
    let secondary: RateLimitWindow?
    let planType: String?
}

private struct RateLimitWindow: Decodable {
    let usedPercent: Int
    let windowDurationMins: Int?
    let resetsAt: Int?
}
