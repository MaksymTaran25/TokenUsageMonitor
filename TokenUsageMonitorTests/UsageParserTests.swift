// Token Usage Monitor
// An unofficial, open-source tool for monitoring Claude usage.
// Not affiliated with or endorsed by Anthropic. Use at your own risk.

import XCTest
@testable import TokenUsageMonitor

final class UsageParserTests: XCTestCase {

    // MARK: - Temporary directory helpers

    private var tmpDir: URL!

    override func setUpWithError() throws {
        tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tmpDir)
    }

    private func write(_ lines: [String], to filename: String = "test.jsonl") throws -> URL {
        let url = tmpDir.appendingPathComponent(filename)
        try lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    // MARK: - Helpers for building JSONL lines

    private func jsonlEntry(
        model: String = "claude-opus-4-6",
        input: Int = 100,
        output: Int = 200,
        cacheCreation: Int = 0,
        cacheRead: Int = 0,
        timestamp: Date = Date()
    ) -> String {
        let ts = ISO8601DateFormatter().string(from: timestamp)
        return """
        {"timestamp":"\(ts)","message":{"model":"\(model)","usage":{"input_tokens":\(input),"output_tokens":\(output),"cache_creation_input_tokens":\(cacheCreation),"cache_read_input_tokens":\(cacheRead)}}}
        """
    }

    // MARK: - Basic parsing

    func testParseUsage_emptyDirectory_returnsPlaceholder() {
        let result = parseUsage(hours: 24, directory: tmpDir)
        XCTAssertEqual(result.totalTokens, 0)
        XCTAssertEqual(result.messageCount, 0)
        XCTAssertTrue(result.byModel.isEmpty)
    }

    func testParseUsage_noJsonlFiles_returnsPlaceholder() throws {
        try "not a jsonl file".write(
            to: tmpDir.appendingPathComponent("notes.txt"),
            atomically: true, encoding: .utf8
        )
        let result = parseUsage(hours: 24, directory: tmpDir)
        XCTAssertEqual(result.totalTokens, 0)
    }

    func testParseUsage_singleEntry_parsedCorrectly() throws {
        try write([jsonlEntry(input: 100, output: 200)])
        let result = parseUsage(hours: 24, directory: tmpDir)
        XCTAssertEqual(result.inputTokens,  100)
        XCTAssertEqual(result.outputTokens, 200)
        XCTAssertEqual(result.totalTokens,  300)
        XCTAssertEqual(result.messageCount, 1)
    }

    func testParseUsage_windowHours_passedThrough() throws {
        try write([jsonlEntry()])
        let result = parseUsage(hours: 168, directory: tmpDir)
        XCTAssertEqual(result.windowHours, 168)
    }

    // MARK: - Cache token handling

    func testParseUsage_cacheTokens_includedInTotal() throws {
        try write([jsonlEntry(input: 100, output: 200, cacheCreation: 50, cacheRead: 30)])
        let result = parseUsage(hours: 24, directory: tmpDir)
        // total = input + output + cacheCreation + cacheRead = 380
        XCTAssertEqual(result.totalTokens,  380)
        // input/output are reported separately (no cache)
        XCTAssertEqual(result.inputTokens,  100)
        XCTAssertEqual(result.outputTokens, 200)
    }

    // MARK: - Timestamp filtering

    func testParseUsage_entryBeforeCutoff_excluded() throws {
        let old = Date().addingTimeInterval(-25 * 3600) // 25h ago, outside 24h window
        try write([jsonlEntry(timestamp: old)])
        let result = parseUsage(hours: 24, directory: tmpDir)
        XCTAssertEqual(result.messageCount, 0)
        XCTAssertEqual(result.totalTokens,  0)
    }

    func testParseUsage_entryWithinWindow_included() throws {
        let recent = Date().addingTimeInterval(-1 * 3600) // 1h ago, inside 24h window
        try write([jsonlEntry(input: 50, output: 75, timestamp: recent)])
        let result = parseUsage(hours: 24, directory: tmpDir)
        XCTAssertEqual(result.messageCount, 1)
        XCTAssertEqual(result.totalTokens,  125)
    }

    func testParseUsage_mixedTimestamps_onlyRecentIncluded() throws {
        let recent = Date().addingTimeInterval(-1 * 3600)
        let old    = Date().addingTimeInterval(-48 * 3600)
        try write([
            jsonlEntry(input: 100, output: 100, timestamp: recent),
            jsonlEntry(input: 999, output: 999, timestamp: old),
        ])
        let result = parseUsage(hours: 24, directory: tmpDir)
        XCTAssertEqual(result.messageCount, 1)
        XCTAssertEqual(result.totalTokens,  200)
    }

    // MARK: - Model aggregation

    func testParseUsage_multipleEntriesSameModel_aggregated() throws {
        try write([
            jsonlEntry(model: "claude-opus-4-6", input: 100, output: 200),
            jsonlEntry(model: "claude-opus-4-6", input: 50,  output: 100),
        ])
        let result = parseUsage(hours: 24, directory: tmpDir)
        XCTAssertEqual(result.messageCount,  2)
        XCTAssertEqual(result.totalTokens,   450)
        XCTAssertEqual(result.byModel.count, 1)
        XCTAssertEqual(result.byModel[0].model,        "claude-opus-4-6")
        XCTAssertEqual(result.byModel[0].messageCount, 2)
        XCTAssertEqual(result.byModel[0].inputTokens,  150)
        XCTAssertEqual(result.byModel[0].outputTokens, 300)
    }

    func testParseUsage_multipleModels_sortedByTotalDescending() throws {
        try write([
            jsonlEntry(model: "claude-haiku-4-5-20251001", input: 10, output: 20),
            jsonlEntry(model: "claude-opus-4-6",           input: 500, output: 1000),
            jsonlEntry(model: "claude-sonnet-4-6",         input: 100, output: 200),
        ])
        let result = parseUsage(hours: 24, directory: tmpDir)
        XCTAssertEqual(result.byModel.count, 3)
        XCTAssertEqual(result.byModel[0].model, "claude-opus-4-6")
        XCTAssertEqual(result.byModel[1].model, "claude-sonnet-4-6")
        XCTAssertEqual(result.byModel[2].model, "claude-haiku-4-5-20251001")
    }

    // MARK: - Malformed input

    func testParseUsage_malformedLines_skipped() throws {
        try write([
            "not valid json",
            "{}",
            "{\"timestamp\":\"bad-date\",\"message\":{\"model\":\"x\",\"usage\":{\"input_tokens\":0,\"output_tokens\":0}}}",
            jsonlEntry(input: 10, output: 20),
        ])
        let result = parseUsage(hours: 24, directory: tmpDir)
        // Only the valid entry with non-zero tokens should be counted
        XCTAssertEqual(result.messageCount, 1)
        XCTAssertEqual(result.totalTokens,  30)
    }

    func testParseUsage_zeroTokenEntry_excluded() throws {
        try write([
            jsonlEntry(input: 0, output: 0),
            jsonlEntry(input: 5, output: 10),
        ])
        let result = parseUsage(hours: 24, directory: tmpDir)
        XCTAssertEqual(result.messageCount, 1)
        XCTAssertEqual(result.totalTokens,  15)
    }

    func testParseUsage_emptyLines_skipped() throws {
        try write([
            "",
            "   ",
            jsonlEntry(input: 20, output: 40),
            "",
        ])
        let result = parseUsage(hours: 24, directory: tmpDir)
        XCTAssertEqual(result.messageCount, 1)
    }

    // MARK: - Multiple files

    func testParseUsage_multipleFiles_allCounted() throws {
        try write([jsonlEntry(input: 100, output: 100)], to: "a.jsonl")
        try write([jsonlEntry(input: 200, output: 200)], to: "b.jsonl")
        let result = parseUsage(hours: 24, directory: tmpDir)
        XCTAssertEqual(result.messageCount, 2)
        XCTAssertEqual(result.totalTokens,  600)
    }

    // MARK: - Model fallback

    func testParseUsage_modelInRootObject_usedAsFallback() throws {
        let ts = ISO8601DateFormatter().string(from: Date())
        let line = """
        {"timestamp":"\(ts)","model":"claude-sonnet-4-6","message":{"usage":{"input_tokens":10,"output_tokens":20}}}
        """
        try write([line])
        let result = parseUsage(hours: 24, directory: tmpDir)
        XCTAssertEqual(result.messageCount,       1)
        XCTAssertEqual(result.byModel.first?.model, "claude-sonnet-4-6")
    }
}
