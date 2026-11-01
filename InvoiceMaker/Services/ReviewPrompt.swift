import Foundation
import SliceRating

/// Asks for an App Store rating at happy moments, spaced out (SliceRating):
/// 1. the first document sent;
/// 2. the first invoice marked paid, at least 30 days after ask 1;
/// 3. the 10th document sent, at least 90 days after ask 2.
/// Never twice in one app version. iOS also limits the pop-up to 3 a year
/// and skips it once the user has rated, so the app can't over-ask.
@MainActor
enum ReviewPrompt {
    enum Moment: Equatable {
        case sent
        case markedPaid

        var rating: RatingMoment {
            switch self {
            case .sent: RatingMoment("sent")
            case .markedPaid: RatingMoment("markedPaid")
            }
        }
    }

    /// The saved values keep Duly's v1.0 names: reviewPromptCount, reviewPromptLastDate,
    /// reviewPromptLastVersion, reviewPromptSentCount.
    static let keyPrefix = "reviewPrompt"
    static let legacyAskedKey = "reviewPromptShown"  // v1.0: true after the first-send ask

    static let steps = [
        RatingStep(after: Moment.sent.rating),
        RatingStep(after: Moment.markedPaid.rating, daysSinceLastAsk: 30),
        RatingStep(after: Moment.sent.rating, count: 10, daysSinceLastAsk: 90),
    ]

    static func prompt(version: String = AppInfo.version, defaults: UserDefaults = .standard) -> RatingPrompt {
        RatingPrompt(steps: steps, keyPrefix: keyPrefix, defaults: defaults, version: version)
    }

    /// Records the moment and returns true when the rating pop-up should show now.
    static func shouldAsk(
        after moment: Moment, now: Date = .now, version: String = AppInfo.version, defaults: UserDefaults = .standard
    ) -> Bool {
        let rating = prompt(version: version, defaults: defaults)
        migrateLegacy(rating, now: now)
        return rating.record(moment.rating, now: now)
    }

    /// Asks after `moment`, a second later so a closing sheet doesn't hide it.
    static func ask(after moment: Moment) {
        guard shouldAsk(after: moment) else { return }
        Task {
            try? await Task.sleep(for: .seconds(1))
            RatingPrompt.requestReview()
        }
    }

    /// v1.0 users who were already asked once: count it, and start the 30-day clock now.
    private static func migrateLegacy(_ rating: RatingPrompt, now: Date) {
        guard rating.defaults.bool(forKey: legacyAskedKey), rating.defaults.object(forKey: keyPrefix + "Count") == nil
        else { return }
        rating.askCount = 1
        rating.lastAskDate = now
        rating.setCount(1, of: Moment.sent.rating)
    }
}
