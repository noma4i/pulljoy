import CryptoKit
import Foundation
import Network
import Security

/// `repo` and `read:org` are the narrowest scopes that can still see pull
/// requests in private repositories and review requests that arrived through a team.
public let githubScopes = "repo read:org"

public struct OAuthApp: Sendable, Equatable {
    public var clientID: String
    public var clientSecret: String

    public init(clientID: String, clientSecret: String) {
        self.clientID = clientID
        self.clientSecret = clientSecret
    }
}

public enum SignInError: Error, LocalizedError, Equatable {
    case github(String)
    case denied
    case timedOut
    case incomplete
    case http(Int)
    case listener(String)

    public var errorDescription: String? {
        switch self {
        case .github(let message): message
        case .denied: "Sign-in was cancelled in the browser."
        case .timedOut: "Sign-in took too long. Try again."
        case .incomplete: "GitHub sent back an incomplete sign-in response"
        case .http(let status): "GitHub returned \(status) during sign-in"
        case .listener(let message): "Couldn't listen for the browser: \(message)"
        }
    }
}

/// Posts a form as JSON and returns the JSON response body.
public protocol HTTPPoster: Sendable {
    func postJSON(_ url: URL, body: [String: String]) async throws -> Data
}

public struct URLSessionPoster: HTTPPoster {
    public init() {}

    public func postJSON(_ url: URL, body: [String: String]) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw SignInError.http(http.statusCode)
        }
        return data
    }
}

/// GitHub's web application flow with PKCE: the browser signs the user in and
/// is redirected to a one-shot listener on 127.0.0.1, which trades the code for a token.
public struct BrowserSignIn: Sendable {
    static let authorizeURL = URL(string: "https://github.com/login/oauth/authorize")!
    static let accessTokenURL = URL(string: "https://github.com/login/oauth/access_token")!

    private struct TokenResponse: Decodable {
        var access_token: String?
        var error: String?
        var error_description: String?
    }

    public let app: OAuthApp
    private let openURL: @Sendable (URL) -> Void
    private let poster: any HTTPPoster
    private let timeout: Duration

    public init(
        app: OAuthApp,
        openURL: @escaping @Sendable (URL) -> Void,
        poster: any HTTPPoster = URLSessionPoster(),
        timeout: Duration = .seconds(300)
    ) {
        self.app = app
        self.openURL = openURL
        self.poster = poster
        self.timeout = timeout
    }

    /// Opens the browser and returns the access token once the user approves.
    public func signIn() async throws -> String {
        let receiver = try LoopbackReceiver()
        defer { receiver.stop() }
        let port = try await receiver.start()

        let redirect = "http://127.0.0.1:\(port)/callback"
        let verifier = Self.randomToken()
        let state = Self.randomToken()
        openURL(Self.authorizationURL(app: app, redirect: redirect, state: state, verifier: verifier))

        let parameters = try await waitForCallback(receiver.callbacks, state: state)
        if parameters["error"] != nil { throw SignInError.denied }
        guard let code = parameters["code"] else { throw SignInError.incomplete }

        let data = try await poster.postJSON(
            Self.accessTokenURL,
            body: [
                "client_id": app.clientID,
                "client_secret": app.clientSecret,
                "code": code,
                "redirect_uri": redirect,
                "code_verifier": verifier,
            ])
        let response = try JSONDecoder().decode(TokenResponse.self, from: data)
        if let token = response.access_token { return token }
        let reason = response.error ?? "unknown_error"
        throw SignInError.github(response.error_description.map { "\(reason): \($0)" } ?? reason)
    }

    /// A callback with another state is somebody else's request; it is
    /// answered by the receiver and ignored here.
    private func waitForCallback(_ callbacks: AsyncStream<[String: String]>, state: String) async throws -> [String: String] {
        try await withThrowingTaskGroup(of: [String: String].self) { group in
            group.addTask {
                for await parameters in callbacks where parameters["state"] == state { return parameters }
                throw CancellationError()
            }
            group.addTask {
                try await Task.sleep(for: timeout)
                throw SignInError.timedOut
            }
            defer { group.cancelAll() }
            guard let first = try await group.next() else { throw CancellationError() }
            return first
        }
    }

    static func authorizationURL(app: OAuthApp, redirect: String, state: String, verifier: String) -> URL {
        var components = URLComponents(url: authorizeURL, resolvingAgainstBaseURL: false) ?? URLComponents()
        components.queryItems = [
            URLQueryItem(name: "client_id", value: app.clientID),
            URLQueryItem(name: "redirect_uri", value: redirect),
            URLQueryItem(name: "scope", value: githubScopes),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge", value: challenge(for: verifier)),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
        ]
        return components.url ?? authorizeURL
    }

    static func challenge(for verifier: String) -> String {
        base64URL(Data(SHA256.hash(data: Data(verifier.utf8))))
    }

    static func randomToken() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return base64URL(Data(bytes))
    }

    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

/// Listens on a free loopback port and reports the query of each `/callback`
/// request, answering the browser with a page that says it can be closed.
final class LoopbackReceiver: @unchecked Sendable {
    let callbacks: AsyncStream<[String: String]>
    private let continuation: AsyncStream<[String: String]>.Continuation
    private let listener: NWListener
    private let queue = DispatchQueue(label: "PullJoy.signin")

    init() throws {
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: .ipv4(.loopback), port: .any)
        do {
            listener = try NWListener(using: parameters)
        } catch {
            throw SignInError.listener(error.localizedDescription)
        }
        (callbacks, continuation) = AsyncStream.makeStream()
    }

    func start() async throws -> Int {
        listener.newConnectionHandler = { [continuation, queue] connection in
            Self.serve(connection, on: queue, continuation: continuation)
        }
        return try await withCheckedThrowingContinuation { (waiting: CheckedContinuation<Int, Error>) in
            let once = ContinuationOnce(waiting)
            listener.stateUpdateHandler = { [listener] state in
                switch state {
                case .ready:
                    if let port = listener.port {
                        once.resume(returning: Int(port.rawValue))
                    } else {
                        once.resume(throwing: SignInError.listener("no port"))
                    }
                case .failed(let error), .waiting(let error):
                    once.resume(throwing: SignInError.listener(error.localizedDescription))
                default:
                    break
                }
            }
            listener.start(queue: queue)
        }
    }

    func stop() {
        listener.cancel()
        continuation.finish()
    }

    private static func serve(_ connection: NWConnection, on queue: DispatchQueue, continuation: AsyncStream<[String: String]>.Continuation)
    {
        connection.start(queue: queue)
        read(connection, buffer: Data(), continuation: continuation)
    }

    private static func read(_ connection: NWConnection, buffer: Data, continuation: AsyncStream<[String: String]>.Continuation) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 16 * 1024) { data, _, isComplete, error in
            var buffer = buffer
            if let data { buffer.append(data) }
            switch parseHTTPRequest(buffer) {
            case .complete(let request):
                let response = respond(to: request, continuation: continuation)
                connection.send(content: response.serialized(), completion: .contentProcessed { _ in connection.cancel() })
            case .incomplete where error == nil && !isComplete:
                read(connection, buffer: buffer, continuation: continuation)
            default:
                connection.cancel()
            }
        }
    }

    private static func respond(to request: HTTPRequest, continuation: AsyncStream<[String: String]>.Continuation) -> HTTPResponse {
        guard request.method == "GET", request.path == "/callback" else { return HTTPResponse(status: 404) }
        let items = URLComponents(string: request.target)?.queryItems ?? []
        let parameters = Dictionary(items.compactMap { item in item.value.map { (item.name, $0) } }, uniquingKeysWith: { _, last in last })
        continuation.yield(parameters)
        let page = """
            <!doctype html><meta charset="utf-8"><title>PullJoy</title>\
            <body style="font:16px -apple-system,sans-serif;text-align:center;padding-top:20vh">\
            <h2>You're signed in to PullJoy</h2><p>You can close this tab.</p></body>
            """
        return HTTPResponse(status: 200, headers: ["Content-Type": "text/html; charset=utf-8"], body: Data(page.utf8))
    }
}

private final class ContinuationOnce<Value: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Value, Error>?

    init(_ continuation: CheckedContinuation<Value, Error>) {
        self.continuation = continuation
    }

    func resume(returning value: Value) { take()?.resume(returning: value) }
    func resume(throwing error: Error) { take()?.resume(throwing: error) }

    private func take() -> CheckedContinuation<Value, Error>? {
        lock.withLock {
            defer { continuation = nil }
            return continuation
        }
    }
}
