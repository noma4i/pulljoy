import Foundation
import PullJoyCore

/// Everything a request to GitHub can fail with, kept apart by kind because
/// each kind is handled differently: a 401 signs out, a 403/429 with rate-limit
/// headers waits, a 5xx is retried, and GraphQL errors may carry partial data.
public enum GitHubError: Error, Sendable, Equatable {
    /// A non-2xx response. `headers` are lowercased.
    case http(status: Int, message: String, headers: [String: String])
    /// The request never got an answer: offline, DNS, a dropped connection.
    case network(String)
    /// A 200 whose body carries `errors`. `partialData` is the `data` GitHub
    /// still resolved, as JSON, or nil when there was none.
    case graphql(messages: [String], partialData: Data?)
    /// An answer that doesn't have the shape it must.
    case malformed(String)
}

extension GitHubError: LocalizedError {
    public var errorDescription: String? { describeError(self) }
}

extension Error {
    public var asGitHubError: GitHubError? { self as? GitHubError }
}

extension GitHubError {
    var status: Int? {
        if case .http(let status, _, _) = self { return status }
        return nil
    }

    var messages: [String] {
        switch self {
        case .http(_, let message, _): [message]
        case .network(let message): [message]
        case .graphql(let messages, _): messages
        case .malformed(let message): [message]
        }
    }
}

/// Whether asking again could plausibly answer differently: only GitHub or its
/// edge failing on its own side (a 5xx, including the 502 a terminated query
/// comes back as) or the network dropping. A 401, a rate limit or a GraphQL
/// error answers the same however many times it is asked.
extension GitHubError {
    public var isTransient: Bool {
        switch self {
        case .http(let status, _, _): (500..<600).contains(status)
        case .network: true
        default: false
        }
    }
}

/// A dead token — revoked or expired. Only a 401 means the token itself is no good.
extension GitHubError {
    public var isAuth: Bool { status == 401 }
}

/// When a hit rate limit lifts, or nil if `error` isn't one. GitHub attaches
/// `x-ratelimit-*` headers to nearly every response, so a permission failure
/// is also a 403 carrying them: both the status and the header must hold.
extension GitHubError {
    public func rateLimitReset(now: Date) -> Date? {
        guard case .http(let status, _, let headers) = self, status == 403 || status == 429 else {
            return nil
        }
        // Primary limit: the quota is spent. `x-ratelimit-reset` is Unix seconds.
        if status == 403, headers["x-ratelimit-remaining"] == "0" {
            guard let reset = headers["x-ratelimit-reset"].flatMap(Double.init) else { return nil }
            return Date(timeIntervalSince1970: reset)
        }
        // Secondary limit (abuse detection): seconds from now, not a timestamp.
        if let retryAfter = headers["retry-after"].flatMap(Double.init) {
            return now.addingTimeInterval(retryAfter)
        }
        return nil
    }
}

private let maxMessageLength = 120

/// One line fit for the header. A body that opens like a document rather than a
/// sentence — the HTML page a gateway sends when it gives up — is replaced by
/// the status it arrived under; a real sentence is kept, clipped at a word.
public func describeError(_ error: any Error) -> String {
    let raw: String
    if let gh = error as? GitHubError {
        switch gh {
        case .http(_, let message, _): raw = message
        case .network(let message): raw = message
        case .graphql(let messages, _): raw = messages.joined(separator: "; ")
        case .malformed(let message): raw = message
        }
    } else {
        raw = error.localizedDescription
    }

    let message = raw.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    if message.isEmpty || message.first.map({ "<{[".contains($0) }) == true {
        guard let status = (error as? GitHubError)?.status else { return "Couldn't reach GitHub" }
        return "Couldn't reach GitHub — HTTP \(status)"
    }
    if message.count <= maxMessageLength { return message }
    let cut = String(message.prefix(maxMessageLength))
    guard let lastSpace = cut.lastIndex(of: " ") else { return cut + "…" }
    return String(cut[..<lastSpace]) + "…"
}

// MARK: - OAuth App access restrictions

/// The org GitHub names in a restriction message: "the `acme` organization".
private let restrictionOrgPattern = "`([^`]+)`\\s+organization"

/// Phrases a restriction message carries besides the org, any one of which will
/// do. Loose on purpose: an org named in some other error ("the `acme`
/// organization could not be found") must not read as a restriction, but a
/// reworded restriction still should.
private let restrictionMarkers = ["access restriction", "third-part"]

private let restrictionOrgRegex = try? NSRegularExpression(pattern: restrictionOrgPattern, options: [.caseInsensitive])

/// Orgs one error entry reports as restricting the OAuth app, or none when the
/// entry is about something else. Judged per entry, so a restriction marker in
/// one message never lends itself to an org named in another.
private func organizations(inRestrictionEntry text: String) -> [String] {
    guard restrictionMarkers.contains(where: { text.range(of: $0, options: .caseInsensitive) != nil }) else {
        return []
    }
    let matches = restrictionOrgRegex?.matches(in: text, range: NSRange(text.startIndex..., in: text)) ?? []
    return matches.compactMap { match in
        Range(match.range(at: 1), in: text).map { String(text[$0]) }
    }
}

/// Orgs GitHub named in an OAuth-app restriction error, sorted for stable copy.
extension GitHubError {
    public var restrictedOrganizations: [String] {
        Array(Set(messages.flatMap(organizations(inRestrictionEntry:)))).sorted()
    }
}

/// Whether a restriction is the *only* thing that went wrong. GitHub can report
/// a timeout or a bad field in the same response as the locked-down org, and
/// dropping such a bucket for "one org is restricted" would hide a real failure.
extension GitHubError {
    public var isOnlyRestriction: Bool {
        !messages.isEmpty && messages.allSatisfy { !organizations(inRestrictionEntry: $0).isEmpty }
    }
}

/// The `data` a GraphQL error response still carried.
extension GitHubError {
    public var partialData: Data? {
        if case .graphql(_, let data) = self { return data }
        return nil
    }
}
