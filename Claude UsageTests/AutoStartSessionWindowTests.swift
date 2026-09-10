import XCTest
@testable import Claude_Usage

final class AutoStartSessionWindowTests: XCTestCase {
    private var calendar: Calendar!

    override func setUp() {
        super.setUp()
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    }

    func testDaytimeWindowIncludesStartAndExcludesEndTime() {
        let window = AutoStartSessionWindow(startMinuteOfDay: 6 * 60, endMinuteOfDay: 18 * 60)

        XCTAssertFalse(window.contains(date(hour: 5, minute: 59), calendar: calendar))
        XCTAssertTrue(window.contains(date(hour: 6), calendar: calendar))
        XCTAssertTrue(window.contains(date(hour: 11), calendar: calendar))
        XCTAssertTrue(window.contains(date(hour: 16), calendar: calendar))
        XCTAssertFalse(window.contains(date(hour: 18), calendar: calendar))
        XCTAssertFalse(window.contains(date(hour: 18, minute: 1), calendar: calendar))
    }

    func testOvernightWindowWrapsAcrossMidnight() {
        let window = AutoStartSessionWindow(startMinuteOfDay: 22 * 60, endMinuteOfDay: 2 * 60)

        XCTAssertTrue(window.contains(date(hour: 23), calendar: calendar))
        XCTAssertTrue(window.contains(date(hour: 0, minute: 30), calendar: calendar))
        XCTAssertFalse(window.contains(date(hour: 2), calendar: calendar))
        XCTAssertFalse(window.contains(date(hour: 12), calendar: calendar))
    }

    func testMatchingStartAndEndIsAllDay() {
        let window = AutoStartSessionWindow(startMinuteOfDay: 8 * 60, endMinuteOfDay: 8 * 60)

        XCTAssertTrue(window.contains(date(hour: 3), calendar: calendar))
        XCTAssertTrue(window.contains(date(hour: 8), calendar: calendar))
        XCTAssertTrue(window.contains(date(hour: 20), calendar: calendar))
    }

    func testProfileWithoutWindowAllowsAutoStartAtAnyTime() {
        let profile = Profile(name: "Work", autoStartSessionEnabled: true)

        XCTAssertTrue(profile.allowsAutoStartSession(at: date(hour: 3), calendar: calendar))
        XCTAssertTrue(profile.allowsAutoStartSession(at: date(hour: 15), calendar: calendar))
    }

    func testProfileWithEnabledWindowRestrictsOutsideWindow() {
        let profile = Profile(
            name: "Work",
            autoStartSessionEnabled: true,
            autoStartSessionWindow: AutoStartSessionWindow(isEnabled: true, startMinuteOfDay: 5 * 60, endMinuteOfDay: 17 * 60)
        )

        XCTAssertTrue(profile.allowsAutoStartSession(at: date(hour: 5), calendar: calendar))
        XCTAssertTrue(profile.allowsAutoStartSession(at: date(hour: 15), calendar: calendar))
        XCTAssertFalse(profile.allowsAutoStartSession(at: date(hour: 17), calendar: calendar))
        XCTAssertFalse(profile.allowsAutoStartSession(at: date(hour: 4, minute: 59), calendar: calendar))
    }

    func testDisablingWindowAllowsAutoStartButPreservesRange() {
        var profile = Profile(
            name: "Work",
            autoStartSessionEnabled: true,
            autoStartSessionWindow: AutoStartSessionWindow(isEnabled: true, startMinuteOfDay: 5 * 60, endMinuteOfDay: 17 * 60)
        )

        // Disabling keeps the configured range so it can be restored on re-enable.
        profile.autoStartSessionWindow?.isEnabled = false

        XCTAssertEqual(profile.autoStartSessionWindow?.startMinuteOfDay, 5 * 60)
        XCTAssertEqual(profile.autoStartSessionWindow?.endMinuteOfDay, 17 * 60)
        XCTAssertTrue(profile.allowsAutoStartSession(at: date(hour: 3), calendar: calendar))

        profile.autoStartSessionWindow?.isEnabled = true

        XCTAssertEqual(profile.autoStartSessionWindow?.startMinuteOfDay, 5 * 60)
        XCTAssertEqual(profile.autoStartSessionWindow?.endMinuteOfDay, 17 * 60)
        XCTAssertFalse(profile.allowsAutoStartSession(at: date(hour: 3), calendar: calendar))
    }

    func testProfileDecodesWithoutWindowAsUnrestricted() throws {
        let profile = Profile(
            name: "Work",
            autoStartSessionEnabled: true,
            autoStartSessionWindow: AutoStartSessionWindow(isEnabled: true, startMinuteOfDay: 5 * 60, endMinuteOfDay: 17 * 60)
        )
        let data = try JSONEncoder().encode(profile)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        json.removeValue(forKey: "autoStartSessionWindow")
        let legacyData = try JSONSerialization.data(withJSONObject: json)

        let decoded = try JSONDecoder().decode(Profile.self, from: legacyData)

        XCTAssertNil(decoded.autoStartSessionWindow)
        XCTAssertTrue(decoded.allowsAutoStartSession(at: date(hour: 3), calendar: calendar))
    }

    func testWindowDecodesWithoutIsEnabledFlagAsEnabled() throws {
        let profile = Profile(
            name: "Work",
            autoStartSessionEnabled: true,
            autoStartSessionWindow: AutoStartSessionWindow(isEnabled: true, startMinuteOfDay: 5 * 60, endMinuteOfDay: 17 * 60)
        )
        let data = try JSONEncoder().encode(profile)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        var windowJSON = try XCTUnwrap(json["autoStartSessionWindow"] as? [String: Any])
        windowJSON.removeValue(forKey: "isEnabled")
        json["autoStartSessionWindow"] = windowJSON
        let legacyData = try JSONSerialization.data(withJSONObject: json)

        let decoded = try JSONDecoder().decode(Profile.self, from: legacyData)

        XCTAssertEqual(decoded.autoStartSessionWindow?.isEnabled, true)
        XCTAssertEqual(decoded.autoStartSessionWindow?.startMinuteOfDay, 5 * 60)
        XCTAssertEqual(decoded.autoStartSessionWindow?.endMinuteOfDay, 17 * 60)
        XCTAssertFalse(decoded.allowsAutoStartSession(at: date(hour: 3), calendar: calendar))
    }

    func testDisabledWindowRoundTripsThroughCodable() throws {
        let profile = Profile(
            name: "Work",
            autoStartSessionEnabled: true,
            autoStartSessionWindow: AutoStartSessionWindow(isEnabled: false, startMinuteOfDay: 5 * 60, endMinuteOfDay: 17 * 60)
        )
        let data = try JSONEncoder().encode(profile)

        let decoded = try JSONDecoder().decode(Profile.self, from: data)

        XCTAssertEqual(decoded.autoStartSessionWindow?.isEnabled, false)
        XCTAssertEqual(decoded.autoStartSessionWindow?.startMinuteOfDay, 5 * 60)
        XCTAssertEqual(decoded.autoStartSessionWindow?.endMinuteOfDay, 17 * 60)
        XCTAssertTrue(decoded.allowsAutoStartSession(at: date(hour: 3), calendar: calendar))
    }

    private func date(hour: Int, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: 2026,
            month: 6,
            day: 12,
            hour: hour,
            minute: minute
        ))!
    }
}
