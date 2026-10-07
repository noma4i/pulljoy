import Foundation
import PullJoyCore
import Testing

@testable import PullJoyKit

private let now = d("2026-08-10T12:00:00Z")

private func pullRequest(_ id: String) -> PullRequest {
    var pr = PullRequest(
        id: id, number: 1, title: "Title", url: "https://github.com/acme/web/pull/1", repository: "acme/web",
        authorLogin: "kate", authorAvatarURL: "", createdAt: now, updatedAt: now, additions: 1, deletions: 1,
        headRefName: "branch", baseRefName: "main", ciStatus: .success, lastCommitPushedAt: now)
    pr.buckets = [.reviewRequested]
    return pr
}

private struct Change: Equatable, Sendable {
    var id: String
    var state: String
}

private final class RecordingClient: GraphQLClient, @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: [Change] = []
    private let failure: GitHubError?

    init(failure: GitHubError? = nil) { self.failure = failure }

    var changes: [Change] { lock.withLock { recorded } }

    func execute(_ query: String, variables: [String: JSONValue]) async throws -> Data {
        if let failure { throw failure }
        let id = variables["id"]?.stringValue ?? ""
        lock.withLock { recorded.append(Change(id: id, state: variables["state"]?.stringValue ?? "")) }
        return try encode(["updateSubscription": ["subscribable": ["id": .string(id)]]])
    }
}

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct SubscriptionTests {
    let defaults = TestDefaults()

    @Test func hidesAnUnsubscribedPullRequestWithoutAFetch() async {
        let store = defaults.makeStore()
        let inbox = Inbox(
            store: store, client: DummyClient(), now: { now },
            fetchPRs: { _, _ in FetchedPullRequests(prs: [pullRequest("PR_1"), pullRequest("PR_2")]) },
            fetchLogin: { _ in "me" })
        await inbox.refresh()
        #expect(inbox.snapshot.items.map(\.pr.id) == ["PR_1", "PR_2"])

        store.unsubscribe("PR_1")
        inbox.reclassify()
        #expect(inbox.snapshot.items.map(\.pr.id) == ["PR_2"])

        store.resubscribe("PR_1")
        inbox.reclassify()
        #expect(inbox.snapshot.items.map(\.pr.id) == ["PR_1", "PR_2"])
    }

    @Test func tellsGitHubToUnsubscribeAndToSubscribeAgain() async throws {
        let client = RecordingClient()
        let inbox = Inbox(store: defaults.makeStore(), client: client)

        #expect(try await inbox.setSubscribed(false, prID: "PR_1") == .changed)
        #expect(try await inbox.setSubscribed(true, prID: "PR_1") == .changed)

        #expect(client.changes == [Change(id: "PR_1", state: "UNSUBSCRIBED"), Change(id: "PR_1", state: "SUBSCRIBED")])
    }

    @Test func reportsAnOrganizationThatDoesNotAllowTheApp() async throws {
        let client = RecordingClient(failure: .graphql(messages: [restrictionMessage("awesome-print")], partialData: nil))
        let inbox = Inbox(store: defaults.makeStore(), client: client)

        #expect(try await inbox.setSubscribed(false, prID: "PR_1") == .refusedByOrganization("awesome-print"))
    }

    @Test func passesGitHubsRefusalOn() async {
        let client = RecordingClient(
            failure: .graphql(messages: ["The 'updateSubscription' field requires one of the following scopes"], partialData: nil))
        let inbox = Inbox(store: defaults.makeStore(), client: client)

        await #expect(throws: GitHubError.self) { try await inbox.setSubscribed(false, prID: "PR_1") }
    }

    @Test func refusesWhenSignedOut() async {
        let inbox = Inbox(store: defaults.makeStore())

        await #expect(throws: GitHubError.self) { try await inbox.setSubscribed(false, prID: "PR_1") }
    }
}
