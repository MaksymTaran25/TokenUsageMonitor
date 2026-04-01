// Token Usage Monitor
// An unofficial, open-source tool for monitoring Claude usage.
// Not affiliated with or endorsed by Anthropic. Use at your own risk.

import XCTest

final class UsageDataTests: XCTestCase {

    // MARK: - formatTokens

    func testFormatTokens_belowThousand() {
        XCTAssertEqual(formatTokens(0), "0")
        XCTAssertEqual(formatTokens(999), "999")
    }

    func testFormatTokens_thousands() {
        XCTAssertEqual(formatTokens(1_000), "1k")
        XCTAssertEqual(formatTokens(15_500), "16k")
        XCTAssertEqual(formatTokens(999_999), "1000k")
    }

    func testFormatTokens_millions() {
        XCTAssertEqual(formatTokens(1_000_000), "1.0M")
        XCTAssertEqual(formatTokens(1_500_000), "1.5M")
        XCTAssertEqual(formatTokens(156_300_000), "156.3M")
    }

    // MARK: - QuotaBucket.displayName

    func testBucketDisplayName_knownKeys() {
        XCTAssertEqual(makeBucket("five_hour").displayName,  "Five hours")
        XCTAssertEqual(makeBucket("seven_day").displayName,  "Seven days")
        XCTAssertEqual(makeBucket("session").displayName,    "Session")
        XCTAssertEqual(makeBucket("weekly").displayName,     "Weekly")
        XCTAssertEqual(makeBucket("monthly").displayName,    "Monthly")
    }

    func testBucketDisplayName_unknownKey_capitalizesFirst() {
        XCTAssertEqual(makeBucket("custom_limit").displayName, "Custom_limit")
    }

    // MARK: - QuotaBucket.status

    func testBucketStatus_normal() {
        XCTAssertEqual(makeBucket("session", utilization: 0).status,  .normal)
        XCTAssertEqual(makeBucket("session", utilization: 59).status, .normal)
    }

    func testBucketStatus_warning() {
        XCTAssertEqual(makeBucket("session", utilization: 60).status, .warning)
        XCTAssertEqual(makeBucket("session", utilization: 84).status, .warning)
    }

    func testBucketStatus_critical() {
        XCTAssertEqual(makeBucket("session", utilization: 85).status,  .critical)
        XCTAssertEqual(makeBucket("session", utilization: 100).status, .critical)
    }

    // MARK: - ModelSnapshot.shortName

    func testShortName_opusWithVersion() {
        let m = makeModel("claude-opus-4-6")
        XCTAssertEqual(m.shortName, "Opus 4.6")
    }

    func testShortName_sonnetWithVersion() {
        let m = makeModel("claude-sonnet-4-6")
        XCTAssertEqual(m.shortName, "Sonnet 4.6")
    }

    func testShortName_haikuWithVersion() {
        let m = makeModel("claude-haiku-4-5-20251001")
        XCTAssertEqual(m.shortName, "Haiku 4.5")
    }

    func testShortName_unknownModel_returnsRaw() {
        let m = makeModel("gpt-4o")
        XCTAssertEqual(m.shortName, "gpt-4o")
    }

    // MARK: - UsageSnapshot.primaryBucket

    func testPrimaryBucket_prefersSession() {
        let session  = makeBucket("session",   utilization: 50)
        let fiveHour = makeBucket("five_hour", utilization: 10)
        let snap = makeSnapshot(buckets: [fiveHour, session])
        XCTAssertEqual(snap.primaryBucket?.name, "session")
    }

    func testPrimaryBucket_fallsBackToFirst() {
        let fiveHour = makeBucket("five_hour", utilization: 10)
        let sevenDay = makeBucket("seven_day", utilization: 75)
        let snap = makeSnapshot(buckets: [fiveHour, sevenDay])
        XCTAssertEqual(snap.primaryBucket?.name, "five_hour")
    }

    func testPrimaryBucket_emptyBuckets_returnsNil() {
        let snap = makeSnapshot(buckets: [])
        XCTAssertNil(snap.primaryBucket)
    }

    // MARK: - UsageSnapshot JSON round-trip

    func testSnapshotCodable_roundTrip() throws {
        let original = UsageSnapshot(
            buckets:         [makeBucket("five_hour", utilization: 44)],
            totalTokens:     1_000_000,
            inputTokens:     17_000,
            outputTokens:    418_000,
            messageCount:    2151,
            byModel:         [makeModel("claude-opus-4-6")],
            windowHours:     24,
            lastUpdated:     Date(timeIntervalSince1970: 0),
            monthlyTokens:   200_000_000,
            monthlyMessages: 2484
        )

        let data     = try JSONEncoder().encode(original)
        let decoded  = try JSONDecoder().decode(UsageSnapshot.self, from: data)

        XCTAssertEqual(decoded.totalTokens,     original.totalTokens)
        XCTAssertEqual(decoded.inputTokens,     original.inputTokens)
        XCTAssertEqual(decoded.outputTokens,    original.outputTokens)
        XCTAssertEqual(decoded.messageCount,    original.messageCount)
        XCTAssertEqual(decoded.windowHours,     original.windowHours)
        XCTAssertEqual(decoded.monthlyTokens,   original.monthlyTokens)
        XCTAssertEqual(decoded.monthlyMessages, original.monthlyMessages)
        XCTAssertEqual(decoded.buckets.first?.name,        "five_hour")
        XCTAssertEqual(decoded.buckets.first?.utilization, 44)
        XCTAssertEqual(decoded.byModel.first?.model,       "claude-opus-4-6")
    }

    // MARK: - Helpers

    private func makeBucket(_ name: String, utilization: Double = 0) -> QuotaBucket {
        QuotaBucket(name: name, utilization: utilization, resetsAt: nil)
    }

    private func makeModel(_ model: String) -> ModelSnapshot {
        ModelSnapshot(model: model, totalTokens: 0, inputTokens: 0, outputTokens: 0, messageCount: 0)
    }

    private func makeSnapshot(buckets: [QuotaBucket]) -> UsageSnapshot {
        UsageSnapshot(
            buckets: buckets, totalTokens: 0, inputTokens: 0,
            outputTokens: 0, messageCount: 0, byModel: [],
            windowHours: 24, lastUpdated: .now,
            monthlyTokens: 0, monthlyMessages: 0
        )
    }
}
