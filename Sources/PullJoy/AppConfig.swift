import Foundation
import PullJoyKit

/// What differs between a packaged build and one run straight from `swift run`.
enum AppConfig {
    /// Running from inside an `.app` bundle rather than a bare executable.
    static let isPackaged = Bundle.main.bundleURL.pathExtension == "app"

    /// A dev run gets its own name, so it never shares the installed app's
    /// settings or Keychain item.
    static let appName = isPackaged ? "PullJoy" : "PullJoy Dev"

    static let version =
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0-dev"

    /// Two ports for the same reason as two names: a dev build next to an
    /// installed one must not fight it for the socket.
    static let mcpPort = isPackaged ? 7855 : 7856

    /// Baked into Info.plist at bundle time. The environment wins so a dev run
    /// can use its own OAuth App, and a `PullJoyGitHubClientID` default
    /// (`defaults write <bundle id> PullJoyGitHubClientID <id>`) lets an
    /// installed build be pointed at one without rebuilding.
    static var githubOAuthApp: OAuthApp? {
        guard let clientID = setting("PullJoyGitHubClientID", environment: "PULLJOY_GITHUB_CLIENT_ID"),
            let clientSecret = setting("PullJoyGitHubClientSecret", environment: "PULLJOY_GITHUB_CLIENT_SECRET")
        else { return nil }
        return OAuthApp(clientID: clientID, clientSecret: clientSecret)
    }

    private static func setting(_ key: String, environment: String) -> String? {
        let fromEnvironment = ProcessInfo.processInfo.environment[environment]
        let fromDefaults = UserDefaults.standard.string(forKey: key)
        let fromBundle = Bundle.main.object(forInfoDictionaryKey: key) as? String
        return [fromEnvironment, fromDefaults, fromBundle].compactMap { $0?.trimmingCharacters(in: .whitespaces) }.first { !$0.isEmpty }
    }

    /// Where new releases are looked for, as `owner/repo`; nil turns the check
    /// off. Set at bundle time, since only the publisher knows which repository
    /// its releases — and version numbers — come from.
    static let updateRepository: String? = {
        let value = Bundle.main.object(forInfoDictionaryKey: "PullJoyUpdateRepository") as? String
        return value?.isEmpty == false ? value : nil
    }()

    static var defaults: UserDefaults {
        isPackaged ? .standard : UserDefaults(suiteName: "PullJoy.dev") ?? .standard
    }

    static let sourceURL = URL(string: "https://github.com/noma4i/pulljoy")!
    static let originalURL = URL(string: "https://github.com/omgovich/pullover")!
    static let mcpSetupURL = URL(string: "https://github.com/noma4i/pulljoy/blob/main/MCP.md")!
}
