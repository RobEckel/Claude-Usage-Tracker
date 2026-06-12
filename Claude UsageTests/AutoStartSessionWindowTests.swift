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

    func testProfileDecodesWithoutWindowAsUnrestricted() throws {
        let profile = Profile(name: "Work", autoStartSessionEnabled: true)
        let data = try JSONEncoder().encode(profile)

        let decoded = try JSONDecoder().decode(Profile.self, from: data)

        XCTAssertNil(decoded.autoStartSessionWindow)
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
