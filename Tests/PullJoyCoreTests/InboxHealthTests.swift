import Testing

@testable import PullJoyCore

@Suite struct InboxHealthTests {
    @Test("a failed fetch is never read as an empty inbox") func failed() {
        let health = InboxHealth(InboxSnapshot(status: .error, errorMessage: "offline"))
        #expect(health == .failed)
        #expect(health.headline == "Couldn't refresh")
    }

    @Test("a fetch that left an organization out is not inbox zero") func partial() {
        let health = InboxHealth(InboxSnapshot(status: .ready, errorMessage: "the acme organization"))
        #expect(health == .partial("the acme organization"))
        #expect(health.headline == "Nothing visible waiting")
        #expect(health.emptyTitle == "Nothing visible waiting")
    }

    @Test("a complete, empty fetch is clear") func clear() {
        let health = InboxHealth(InboxSnapshot(status: .ready))
        #expect(health == .clear)
        #expect(health.headline == "All clear")
        #expect(health.emptyTitle == "Inbox zero")
    }
}
