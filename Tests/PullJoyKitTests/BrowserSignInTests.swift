import CryptoKit
import Foundation
import Testing

@testable import PullJoyKit

private actor RecordingPoster: HTTPPoster {
    private(set) var bodies: [[String: String]] = []
    private let reply: Data

    init(reply: String = #"{"access_token":"gho_test"}"#) {
        self.reply = Data(reply.utf8)
    }

    func postJSON(_ url: URL, body: [String: String]) async throws -> Data {
        bodies.append(body)
        return reply
    }
}

private let app = OAuthApp(clientID: "client-id", clientSecret: "client-secret")

private func parameters(of url: URL) -> [String: String] {
    let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
    return Dictionary(items.compactMap { item in item.value.map { (item.name, $0) } }, uniquingKeysWith: { _, last in last })
}

/// Plays the browser: follows the redirect GitHub would send, with `query` appended.
private func browser(_ query: @escaping @Sendable (_ state: String) -> [String]) -> @Sendable (URL) -> Void {
    { url in
        let opened = parameters(of: url)
        guard let redirect = opened["redirect_uri"], let state = opened["state"] else { return }
        Task {
            for item in query(state) {
                _ = try? await URLSession.shared.data(from: URL(string: "\(redirect)?\(item)")!)
            }
        }
    }
}

@Suite struct BrowserSignInTests {
    @Test func returnsTheTokenAndProvesTheCodeWithPKCE() async throws {
        let poster = RecordingPoster()
        let opened = Box<URL?>(nil)
        let play = browser { ["code=the-code&state=\($0)"] }
        let flow = BrowserSignIn(
            app: app,
            openURL: {
                opened.value = $0
                play($0)
            }, poster: poster)

        #expect(try await flow.signIn() == "gho_test")

        let url = try #require(opened.value)
        let query = parameters(of: url)
        #expect(url.host == "github.com")
        #expect(query["client_id"] == "client-id")
        #expect(query["scope"] == "repo read:org")
        #expect(query["code_challenge_method"] == "S256")
        #expect(query["redirect_uri"]?.hasPrefix("http://127.0.0.1:") == true)

        let body = try #require(await poster.bodies.first)
        #expect(body["code"] == "the-code")
        #expect(body["client_secret"] == "client-secret")
        #expect(body["redirect_uri"] == query["redirect_uri"])
        let verifier = try #require(body["code_verifier"])
        #expect(BrowserSignIn.challenge(for: verifier) == query["code_challenge"])
    }

    @Test func ignoresACallbackWithAnotherState() async throws {
        let poster = RecordingPoster()
        let flow = BrowserSignIn(
            app: app, openURL: browser { ["code=forged&state=other", "code=real&state=\($0)"] }, poster: poster)

        #expect(try await flow.signIn() == "gho_test")
        #expect(await poster.bodies.map { $0["code"] } == ["real"])
    }

    @Test func reportsADeniedAuthorization() async {
        let flow = BrowserSignIn(app: app, openURL: browser { ["error=access_denied&state=\($0)"] }, poster: RecordingPoster())

        await #expect(throws: SignInError.denied) { try await flow.signIn() }
    }

    @Test func reportsACallbackWithoutACode() async {
        let flow = BrowserSignIn(app: app, openURL: browser { ["state=\($0)"] }, poster: RecordingPoster())

        await #expect(throws: SignInError.incomplete) { try await flow.signIn() }
    }

    @Test func reportsWhyGitHubRefusedTheCode() async {
        let poster = RecordingPoster(reply: #"{"error":"bad_verification_code","error_description":"The code has expired."}"#)
        let flow = BrowserSignIn(app: app, openURL: browser { ["code=old&state=\($0)"] }, poster: poster)

        await #expect(throws: SignInError.github("bad_verification_code: The code has expired.")) { try await flow.signIn() }
    }

    @Test func givesUpWhenTheBrowserNeverComesBack() async {
        let flow = BrowserSignIn(app: app, openURL: { _ in }, poster: RecordingPoster(), timeout: .milliseconds(200))

        await #expect(throws: SignInError.timedOut) { try await flow.signIn() }
    }

    @Test func stopsWaitingWhenCancelled() async {
        let flow = BrowserSignIn(app: app, openURL: { _ in }, poster: RecordingPoster())
        let task = Task { try await flow.signIn() }
        task.cancel()

        await #expect(throws: CancellationError.self) { try await task.value }
    }

    @Test func answersOnlyTheCallbackPath() async throws {
        let receiver = try LoopbackReceiver()
        defer { receiver.stop() }
        let port = try await receiver.start()

        let (_, other) = try await URLSession.shared.data(from: URL(string: "http://127.0.0.1:\(port)/elsewhere")!)
        #expect((other as? HTTPURLResponse)?.statusCode == 404)

        let (page, callback) = try await URLSession.shared.data(from: URL(string: "http://127.0.0.1:\(port)/callback?code=1")!)
        #expect((callback as? HTTPURLResponse)?.statusCode == 200)
        #expect(String(bytes: page, encoding: .utf8)?.contains("signed in") == true)
    }
}
