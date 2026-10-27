import Foundation

/// How often a recurring invoice repeats. Dates are counted from the first
/// invoice's date (the anchor), so a monthly invoice on the 31st goes
/// 31 Jan, 28 Feb, 31 Mar (it doesn't drift to the 28th).
public enum Recurrence: String, CaseIterable, Sendable, Codable {
    case weekly
    case monthly
    case yearly

    /// The anchor plus `count` periods.
    public func occurrence(_ count: Int, from anchor: Date, calendar: Calendar = .current) -> Date {
        let (component, step): (Calendar.Component, Int) =
            switch self {
            case .weekly: (.day, 7)
            case .monthly: (.month, 1)
            case .yearly: (.year, 1)
            }
        // Adding days, months or years to a valid date always gives a date in the calendars we use.
        var result = anchor
        if let date = calendar.date(byAdding: component, value: step * count, to: anchor) { result = date }
        return result
    }

    /// The first occurrence strictly after `date` (never the anchor itself).
    public func next(after date: Date, anchor: Date, calendar: Calendar = .current) -> Date {
        var count = 1
        // Jump close first so a weekly invoice opened after years doesn't loop for long.
        var days = 0
        if let gap = calendar.dateComponents([.day], from: anchor, to: date).day { days = max(0, gap) }
        let approximateDays = switch self {
        case .weekly: 7
        case .monthly: 28
        case .yearly: 365
        }
        count = max(1, days / approximateDays - 1)
        while occurrence(count, from: anchor, calendar: calendar) <= date { count += 1 }
        while count > 1, occurrence(count - 1, from: anchor, calendar: calendar) > date { count -= 1 }
        return occurrence(count, from: anchor, calendar: calendar)
    }
}
