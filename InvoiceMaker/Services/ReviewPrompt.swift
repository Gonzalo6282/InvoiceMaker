import Foundation
import StoreKit
import UIKit

/// Asks for an App Store rating at happy moments, spaced out:
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
    }

    static let legacyAskedKey = "reviewPromptShown"  // v1.0: true after the first-send ask
    static let countKey = "reviewPromptCount"
    static let lastDateKey = "reviewPromptLastDate"
    static let lastVersionKey = "reviewPromptLastVersion"
    static let sentKey = "reviewPromptSentCount"

    /// Records the moment and returns true when the rating pop-up should show now.
    static func shouldAsk(
        after moment: Moment, now: Date = .now, version: String = AppInfo.version, defaults: UserDefaults = .standard
    ) -> Bool {
        migrateLegacy(now: now, defaults: defaults)
        var sent = defaults.integer(forKey: sentKey)
        if moment == .sent {
            sent += 1
            defaults.set(sent, forKey: sentKey)
        }
        let count = defaults.integer(forKey: countKey)
        guard defaults.string(forKey: lastVersionKey) != version else { return false }
        let days = (defaults.object(forKey: lastDateKey) as? Date).map { now.timeIntervalSince($0) / 86_400 } ?? .infinity
        let ask: Bool = switch count {
        case 0: moment == .sent
        case 1: moment == .markedPaid && days >= 30
        case 2: moment == .sent && sent >= 10 && days >= 90
        default: false
        }
        guard ask else { return false }
        defaults.set(count + 1, forKey: countKey)
        defaults.set(now, forKey: lastDateKey)
        defaults.set(version, forKey: lastVersionKey)
        return true
    }

    /// Asks after `moment`, a second later so a closing sheet doesn't hide it.
    static func ask(after moment: Moment) {
        guard shouldAsk(after: moment) else { return }
        Task {
            try? await Task.sleep(for: .seconds(1))
            guard let scene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
            else { return }
            AppStore.requestReview(in: scene)
        }
    }

    /// v1.0 users who were already asked once: count it, and start the 30-day clock now.
    private static func migrateLegacy(now: Date, defaults: UserDefaults) {
        guard defaults.bool(forKey: legacyAskedKey), defaults.object(forKey: countKey) == nil else { return }
        defaults.set(1, forKey: countKey)
        defaults.set(now, forKey: lastDateKey)
        defaults.set(1, forKey: sentKey)
    }
}
