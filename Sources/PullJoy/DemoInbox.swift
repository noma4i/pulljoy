#if DEBUG
    import Foundation
    import PullJoyCore
    import PullJoyKit

    /// An invented inbox for screenshots and trying the interface without a
    /// GitHub account: `PULLJOY_DEMO=1`. Built as raw pull requests rather than
    /// finished rows, so everything shown is something `classify` really produces.
    enum DemoInbox {
        static var isEnabled: Bool { ProcessInfo.processInfo.environment["PULLJOY_DEMO"] == "1" }

        static func makeStore() -> AppStore {
            UserDefaults.standard.removePersistentDomain(forName: "PullJoy.demo")
            return AppStore(defaults: UserDefaults(suiteName: "PullJoy.demo")!)
        }

        @MainActor
        static func makeInbox(store: AppStore) -> Inbox {
            seedSnoozes(store, now: Date())
            return Inbox(
                store: store,
                fetchPRs: { _, _ in FetchedPullRequests(prs: pullRequests(now: Date())) },
                fetchLogin: { _ in me }
            )
        }

        static let me = "alex"

        struct Client: GraphQLClient {
            func execute(_ query: String, variables: [String: JSONValue]) async throws -> Data {
                throw GitHubError.malformed("The demo inbox never talks to GitHub")
            }
        }

        static func seedSnoozes(_ store: AppStore, now: Date) {
            store.snooze("demo-733", type: .untilTime, now: now, hours: 24)
        }

        static func pullRequests(now: Date) -> [PullRequest] {
            func ago(_ minutes: Double) -> Date { now.addingTimeInterval(-minutes * 60) }
            let h = 60.0

            func avatar(_ login: String) -> String {
                "https://api.dicebear.com/9.x/thumbs/png?seed=\(login)&backgroundColor=b6e3f4,c0aede,d1d4f9,ffd5dc,ffdfbf"
            }

            func pr(
                _ number: Int, _ repo: String, _ title: String, by author: String,
                _ additions: Int, _ deletions: Int, ci: CIStatus = .success,
                head: String? = nil, base: String = "main",
                configure: (inout PullRequest) -> Void = { _ in }
            ) -> PullRequest {
                var pr = PullRequest(
                    id: "demo-\(number)", number: number, title: title,
                    url: "https://github.com/\(repo)/pull/\(number)", repository: repo,
                    authorLogin: author, authorAvatarURL: avatar(author),
                    createdAt: ago(3 * 24 * h), updatedAt: ago(30),
                    additions: additions, deletions: deletions,
                    headRefName: head ?? "branch-\(number)", baseRefName: base,
                    ciStatus: ci, lastCommitPushedAt: ago(2 * 24 * h)
                )
                configure(&pr)
                return pr
            }

            func thread(_ id: String, _ comments: [(String, Double)]) -> ReviewThread {
                ReviewThread(id: id, comments: comments.map { ThreadComment(authorLogin: $0.0, createdAt: ago($0.1)) })
            }

            return [
                pr(1204, "northwind/payments", "Retry failed webhooks", by: "jlee", 733, 214, ci: .pending) {
                    $0.buckets = [.reviewRequested]
                    $0.reviewRequestedAt = ago(6 * h)
                },
                pr(3310, "northwind/web", "Cache the search suggestions", by: "nora", 412, 96) {
                    $0.buckets = [.reviewRequested]
                    $0.reviewRequestedAt = ago(40)
                },
                pr(3318, "northwind/web", "Keyboard focus lost in the date picker", by: "omar", 87, 31) {
                    $0.buckets = [.involves]
                    $0.reviewThreads = [
                        thread("t1", [(me, 20 * h), ("omar", 9 * h)]),
                        thread("t2", [(me, 20 * h), ("omar", 8 * h)]),
                        thread("t3", [(me, 20 * h), ("omar", 2 * h)]),
                    ]
                },
                pr(1190, "northwind/payments", "Invoices: data model", by: "omar", 218, 140, head: "invoices-model") {
                    $0.buckets = [.reviewRequested]
                    $0.reviews = [Review(authorLogin: me, state: .commented, submittedAt: ago(20 * h))]
                    $0.reviewRequestedAt = ago(5 * h)
                },
                pr(1191, "northwind/payments", "Invoices: line items", by: "ines", 96, 18, head: "invoices-lines", base: "invoices-model") {
                    $0.buckets = [.involves]
                    $0.reviews = [Review(authorLogin: me, state: .approved, submittedAt: ago(20 * h))]
                    $0.lastCommitPushedAt = ago(7 * h)
                },
                // Third in the stack, but nothing about it is waiting on anyone
                // here: hidden, which is what leaves the dotted gap in the chain.
                pr(1192, "northwind/payments", "Invoices: totals", by: "jlee", 120, 30, head: "invoices-totals", base: "invoices-lines") {
                    $0.buckets = [.involves]
                },
                pr(1193, "northwind/payments", "Invoices: PDF export", by: "nora", 41, 9, head: "invoices-pdf", base: "invoices-totals") {
                    $0.buckets = [.involves]
                    $0.reviews = [Review(authorLogin: me, state: .commented, submittedAt: ago(20 * h))]
                    $0.lastCommitPushedAt = ago(9 * h)
                },
                pr(3301, "northwind/web", "Onboarding checklist", by: me, 234, 4) {
                    $0.buckets = [.author]
                    $0.reviewThreads = [thread("t4", [("nora", 10 * h)]), thread("t5", [("omar", 4 * h)])]
                },
                pr(740, "northwind/ios", "Background sync on cellular", by: me, 573, 24, ci: .failure) {
                    $0.buckets = [.author]
                    $0.lastCommitPushedAt = ago(3 * h)
                },
                pr(1197, "northwind/payments", "Receipt email wording", by: "jlee", 6, 6, ci: .none) {
                    $0.buckets = [.mentions]
                    $0.mentionsAt = [ago(7 * h)]
                },
                pr(3290, "northwind/web", "Remove the legacy chart library", by: me, 12, 304) {
                    $0.buckets = [.author]
                    $0.updatedAt = ago(90)
                },
                pr(733, "northwind/ios", "Update the onboarding illustrations", by: "ines", 8, 8) {
                    $0.buckets = [.reviewRequested]
                    $0.updatedAt = ago(6 * h)
                },
            ]
        }
    }
#else
    import Foundation
    import PullJoyKit

    enum DemoInbox {
        static let isEnabled = false
        static func makeStore() -> AppStore { preconditionFailure("demo mode is not part of release builds") }
        @MainActor static func makeInbox(store: AppStore) -> Inbox { preconditionFailure("demo mode is not part of release builds") }
        struct Client: GraphQLClient {
            func execute(_ query: String, variables: [String: JSONValue]) async throws -> Data {
                preconditionFailure("demo mode is not part of release builds")
            }
        }
    }
#endif
