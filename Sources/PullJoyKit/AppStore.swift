import Foundation
import PullJoyCore

public struct InvalidRepositoryError: Error, LocalizedError, Equatable {
    public var input: String
    public var errorDescription: String? { "Repository needs to look like owner/repo — got \"\(input)\"" }
}

/// Preferences and snoozes, persisted in `UserDefaults`. Both are stored as JSON
/// blobs rather than one key per field, so a settings shape written by an
/// older build is decoded — and defaulted field by field — in one place.
public final class AppStore: @unchecked Sendable {
    private static let settingsKey = "settings"
    private static let snoozesKey = "snoozes"
    private static let unsubscribedKey = "unsubscribed"

    private let defaults: UserDefaults
    private let lock = NSLock()

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // Every public accessor takes the lock once and holds it across the whole
    // read-modify-write; `NSLock` is not recursive, so the helpers below assume
    // it is already held.

    public var settings: Preferences {
        lock.withLock { readSettings() }
    }

    /// Atomic against every other call on this store. `change` runs under the
    /// lock, so it must not call back into the store.
    public func updateSettings(_ change: (inout Preferences) -> Void) {
        lock.withLock { modifySettings(change) }
    }

    public func addRepository(_ fullName: String) throws {
        let normalised = fullName.trimmingCharacters(in: .whitespaces).lowercased()
        guard normalised.wholeMatch(of: /[\w.-]+\/[\w.-]+/) != nil else {
            throw InvalidRepositoryError(input: fullName)
        }
        updateSettings { settings in
            if !settings.repositories.contains(normalised) { settings.repositories.append(normalised) }
        }
    }

    public func removeRepository(_ fullName: String) {
        let normalised = fullName.trimmingCharacters(in: .whitespaces).lowercased()
        updateSettings { $0.repositories.removeAll { $0.lowercased() == normalised } }
    }

    public var snoozes: [String: Snooze] {
        lock.withLock { readSnoozes() }
    }

    /// `hours` is required for `.untilTime` and ignored otherwise. `headSHA` is
    /// the pull request's head now, so a push wakes an until-activity snooze.
    public func snooze(_ prId: String, type: SnoozeType, now: Date, hours: Int? = nil, headSHA: String? = nil) {
        let until: Date? = type == .untilTime ? now.addingTimeInterval(TimeInterval((hours ?? 24) * 3600)) : nil
        lock.withLock {
            var next = readSnoozes()
            next[prId] = Snooze(prId: prId, type: type, snoozedAt: now, until: until, headSHA: headSHA)
            writeSnoozes(next)
        }
    }

    public func unsnooze(_ prId: String) {
        lock.withLock {
            var next = readSnoozes()
            next[prId] = nil
            writeSnoozes(next)
        }
    }

    public var unsubscribed: Set<String> {
        lock.withLock { readUnsubscribed() }
    }

    public func unsubscribe(_ prId: String) {
        lock.withLock { writeUnsubscribed(readUnsubscribed().union([prId])) }
    }

    public func resubscribe(_ prId: String) {
        lock.withLock { writeUnsubscribed(readUnsubscribed().subtracting([prId])) }
    }

    // MARK: - Unlocked; callers hold `lock`

    private func readUnsubscribed() -> Set<String> {
        Set(defaults.stringArray(forKey: Self.unsubscribedKey) ?? [])
    }

    private func writeUnsubscribed(_ ids: Set<String>) {
        defaults.set(ids.sorted(), forKey: Self.unsubscribedKey)
    }

    private func readSettings() -> Preferences {
        guard let data = defaults.data(forKey: Self.settingsKey),
            let settings = try? JSONDecoder().decode(Preferences.self, from: data)
        else { return .defaults }
        return settings
    }

    private func modifySettings(_ change: (inout Preferences) -> Void) {
        var next = readSettings()
        change(&next)
        defaults.set(try? JSONEncoder().encode(next), forKey: Self.settingsKey)
    }

    private func readSnoozes() -> [String: Snooze] {
        guard let data = defaults.data(forKey: Self.snoozesKey),
            let snoozes = try? ISODate.makeDecoder().decode([String: Snooze].self, from: data)
        else { return [:] }
        return snoozes
    }

    /// Keeps fractional seconds, so a snooze read back is the instant it was set.
    private func writeSnoozes(_ snoozes: [String: Snooze]) {
        defaults.set(try? ISODate.makeEncoder(fractionalSeconds: true).encode(snoozes), forKey: Self.snoozesKey)
    }
}
