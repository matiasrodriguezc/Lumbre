import Foundation
import Testing
@testable import LumbreCore

@Suite struct SupabaseLumbreAPITests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Argentina/Buenos_Aires")!
        return calendar
    }()

    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 9, day: day, hour: hour, minute: minute))!
    }

    @Test func refillIsLaterTodayWhenTheHourHasNotPassed() {
        let next = SupabaseLumbreAPI.nextOccurrence(of: "08:00:00", after: date(27, 6), calendar: calendar)
        #expect(next == date(27, 8))
    }

    @Test func refillIsTomorrowWhenTheHourAlreadyPassed() {
        let next = SupabaseLumbreAPI.nextOccurrence(of: "08:00:00", after: date(27, 14), calendar: calendar)
        #expect(next == date(28, 8))
    }

    @Test func refillKeepsTheMinutes() {
        let next = SupabaseLumbreAPI.nextOccurrence(of: "09:30:00", after: date(27, 9, 10), calendar: calendar)
        #expect(next == date(27, 9, 30))
    }
}
