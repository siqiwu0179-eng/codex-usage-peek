import Foundation
import XCTest
@testable import CodexUsageCore

final class CodexRateLimitParserTests: XCTestCase {
    func testParsesWeeklyWindowAndConvertsUsedToRemaining() throws {
        let json = #"{"id":2,"result":{"rateLimits":{"limitId":"codex","primary":{"usedPercent":24,"windowDurationMins":10080,"resetsAt":1787201469},"secondary":null,"planType":"plus"},"rateLimitsByLimitId":{"codex":{"limitId":"codex","primary":{"usedPercent":24,"windowDurationMins":10080,"resetsAt":1787201469},"secondary":null,"planType":"plus"}}}}"#
        let fetchedAt = Date(timeIntervalSince1970: 1_000)
        let snapshot = try CodexRateLimitParser.parseResponseLine(Data(json.utf8), fetchedAt: fetchedAt)

        XCTAssertEqual(snapshot.remainingPercent, 76)
        XCTAssertEqual(snapshot.usedPercent, 24)
        XCTAssertEqual(snapshot.windowDurationMinutes, 10_080)
        XCTAssertEqual(snapshot.planType, "plus")
        XCTAssertEqual(snapshot.resetAt, Date(timeIntervalSince1970: 1_787_201_469))
        XCTAssertEqual(snapshot.fetchedAt, fetchedAt)
    }

    func testSelectsWeeklySecondaryInsteadOfShortPrimary() throws {
        let json = #"{"id":2,"result":{"rateLimits":{"primary":{"usedPercent":10,"windowDurationMins":300,"resetsAt":100},"secondary":{"usedPercent":35,"windowDurationMins":10080,"resetsAt":200},"planType":"pro"}}}"#
        let snapshot = try CodexRateLimitParser.parseResponseLine(Data(json.utf8))
        XCTAssertEqual(snapshot.remainingPercent, 65)
        XCTAssertEqual(snapshot.resetAt, Date(timeIntervalSince1970: 200))
    }

    func testRejectsResponseWithoutWeeklyWindow() {
        let json = #"{"id":2,"result":{"rateLimits":{"primary":{"usedPercent":10,"windowDurationMins":300,"resetsAt":100}}}}"#
        XCTAssertThrowsError(try CodexRateLimitParser.parseResponseLine(Data(json.utf8))) { error in
            XCTAssertEqual(error as? CodexRateLimitParserError, .weeklyWindowMissing)
        }
    }
}
