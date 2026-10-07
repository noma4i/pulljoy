import Testing

@testable import PullJoyCore

@Suite struct ReasonTests {
    @Test(
        "is drawn in the colour that says how urgent it is",
        arguments: [
            (Reason.ciRed, Accent.critical), (.changesRequested, .critical), (.mergeConflicts, .critical),
            (.readyToMerge, .positive), (.mentioned, .warning),
            (.waitingOnAuthor, .neutral), (.waitingOnReviewers, .neutral), (.snoozed, .neutral),
            (.reviewRequested, .primary), (.reReviewRequested, .primary), (.newCommits, .primary),
            (.newReplies(3), .primary), (.openThreads(2), .primary),
        ])
    func accent(reason: Reason, accent: Accent) {
        #expect(reason.accent == accent)
    }

    @Test("counts take the singular for one and the plural otherwise") func counts() {
        #expect(Reason.newReplies(1).text == "1 new reply")
        #expect(Reason.newReplies(3).text == "3 new replies")
        #expect(Reason.openThreads(1).text == "1 open thread")
        #expect(Reason.openThreads(2).text == "2 open threads")
    }
}
