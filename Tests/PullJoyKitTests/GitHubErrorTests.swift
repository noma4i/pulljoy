import Foundation
import Testing

@testable import PullJoyKit

private let NOW = d("2026-08-10T12:00:00Z")

private let badGatewayPage = """
    <html>
    <head><title>502 Bad Gateway</title></head>
    <body>
    <center><h1>502 Bad Gateway</h1></center>
    <hr><center>nginx</center>
    </body>
    </html>

    """

private let unrelatedGraphQLError = graphqlError(["Field \"bogus\" does not exist"], data: nil)

@Suite struct RateLimitResetAtTests {
    @Test func readsThePrimaryLimitFromA403WithRemainingExhaustedAndAUnixResetTimestamp() {
        let error = httpError(
            403, "API rate limit exceeded",
            headers: [
                "x-ratelimit-limit": "5000",
                "x-ratelimit-remaining": "0",
                "x-ratelimit-reset": "1786363920",
            ])
        #expect(error.asGitHubError?.rateLimitReset(now: NOW) == d("2026-08-10T12:12:00Z"))
    }

    @Test func readsTheSecondaryLimitFromA429WithRetryAfterSeconds() {
        let error = httpError(429, "You have exceeded a secondary rate limit", headers: ["retry-after": "90"])
        #expect(error.asGitHubError?.rateLimitReset(now: NOW) == d("2026-08-10T12:01:30Z"))
    }

    @Test func readsTheSecondaryLimitFromA403WithRetryAfterSeconds() {
        let error = httpError(403, "You have exceeded a secondary rate limit", headers: ["retry-after": "30"])
        #expect(error.asGitHubError?.rateLimitReset(now: NOW) == d("2026-08-10T12:00:30Z"))
    }

    @Test func doesNotMatchA403WithNoRateLimitHeadersAtAll() {
        #expect(httpError(403, "Forbidden").asGitHubError?.rateLimitReset(now: NOW) == nil)
    }

    @Test func doesNotMatchA403ThatIsAPermissionProblemNotAnExhaustedLimit() {
        let error = httpError(
            403, "Resource not accessible by integration",
            headers: [
                "x-ratelimit-limit": "5000",
                "x-ratelimit-remaining": "4999",
                "x-ratelimit-reset": "1786363920",
            ])
        #expect(error.asGitHubError?.rateLimitReset(now: NOW) == nil)
    }

    @Test func doesNotMatchA401() {
        let error = httpError(401, "Bad credentials", headers: ["x-ratelimit-remaining": "0", "x-ratelimit-reset": "1786363920"])
        #expect(error.asGitHubError?.rateLimitReset(now: NOW) == nil)
    }

    @Test func doesNotMatchA401CarryingARetryAfterHeaderEither() {
        #expect(httpError(401, "Bad credentials", headers: ["retry-after": "30"]).asGitHubError?.rateLimitReset(now: NOW) == nil)
    }

    @Test func doesNotMatchA404() {
        let error = httpError(404, "Not Found", headers: ["x-ratelimit-remaining": "0", "x-ratelimit-reset": "1786363920"])
        #expect(error.asGitHubError?.rateLimitReset(now: NOW) == nil)
    }

    @Test func doesNotMatchAGraphQLErrorWhichCarriesNoStatus() {
        #expect(unrelatedGraphQLError.asGitHubError?.rateLimitReset(now: NOW) == nil)
    }

    @Test func doesNotMatchAnErrorThatIsNotFromGitHub() {
        #expect(TestError("network down").asGitHubError?.rateLimitReset(now: NOW) == nil)
        #expect(GitHubError.network("network down").asGitHubError?.rateLimitReset(now: NOW) == nil)
    }

    // "does not match a non-Error value": Swift only throws `Error`s.
}

@Suite struct DescribeErrorTests {
    @Test func replacesAnHTMLErrorPageWithTheStatusItArrivedUnder() {
        #expect(describeError(httpError(502, badGatewayPage)) == "Couldn't reach GitHub — HTTP 502")
    }

    @Test func replacesABodyThatOpensLikeJSONRatherThanASentence() {
        let error = httpError(503, #"{"errors":[{"type":"SERVICE_UNAVAILABLE"}]}"#)
        #expect(describeError(error) == "Couldn't reach GitHub — HTTP 503")
    }

    @Test func keepsALongSentenceCutToWhatTheHeaderCanShow() {
        let timeout = httpError(
            502,
            "We couldn't respond to your request in time. Sorry about that. Please try resubmitting your request and contact us if the problem persists."
        )
        #expect(
            describeError(timeout)
                == "We couldn't respond to your request in time. Sorry about that. Please try resubmitting your request and contact us if…")
    }

    @Test func keepsGitHubsOwnMessageWhichIsShortAndWrittenForAHuman() {
        #expect(describeError(httpError(401, "Bad credentials")) == "Bad credentials")
    }

    @Test func keepsAGraphQLErrorWhichArrivesUnderA200() {
        // Swift keeps GitHub's words as they are; octokit prefixed them with its own.
        #expect(describeError(graphqlError(["Could not resolve to a node"], data: nil)) == "Could not resolve to a node")
        #expect(describeError(graphqlError(["One", "Two"], data: nil)) == "One; Two")
    }

    @Test func keepsANetworkFailureMessage() {
        #expect(describeError(GitHubError.network("getaddrinfo ENOTFOUND api.github.com")) == "getaddrinfo ENOTFOUND api.github.com")
    }

    @Test func collapsesTheWhitespaceOfAMessageWorthKeeping() {
        #expect(describeError(TestError("Something\n  went   wrong")) == "Something went wrong")
    }

    @Test func fallsBackWithoutAStatusWhenThereIsNothingReadableAndNothingThrownByHTTP() {
        #expect(describeError(TestError("")) == "Couldn't reach GitHub")
        #expect(describeError(TestError(badGatewayPage)) == "Couldn't reach GitHub")
        #expect(describeError(GitHubError.network("")) == "Couldn't reach GitHub")
    }

    @Test func isWhatAGitHubErrorReportsAsItsLocalizedDescription() {
        #expect(httpError(502, badGatewayPage).localizedDescription == "Couldn't reach GitHub — HTTP 502")
    }

    // "describes something thrown that is not an Error at all": Swift only throws `Error`s.
}

@Suite struct RestrictedOrganizationsTests {
    @Test func readsTheOrgGitHubNamedInTheError() {
        #expect((graphqlError([restrictionMessage("status-im")], data: nil).asGitHubError?.restrictedOrganizations ?? []) == ["status-im"])
    }

    @Test func collectsEveryOrgWhenSeveralAreNamed() {
        let error = graphqlError(
            [
                "the `status-im` organization has enabled OAuth App access restrictions",
                "the `acme` organization has enabled OAuth App access restrictions",
            ], data: nil)
        #expect(error.asGitHubError?.restrictedOrganizations ?? [] == ["acme", "status-im"])
    }

    @Test func isEmptyForAnUnrelatedFailure() {
        #expect((unrelatedGraphQLError.asGitHubError?.restrictedOrganizations ?? []).isEmpty)
        #expect((TestError(restrictionMessage("status-im")).asGitHubError?.restrictedOrganizations ?? []).isEmpty)
    }

    @Test func readsTheOrgOutOfAPlain403WhichCarriesItOnlyOnItsMessage() {
        #expect((httpError(403, restrictionMessage("status-im")).asGitHubError?.restrictedOrganizations ?? []) == ["status-im"])
    }

    @Test func readsGitHubsFullRealMessage() {
        let real =
            "Although you appear to have the correct authorization credentials, the `acme` organization has enabled OAuth App access restrictions, meaning that data access to third-parties is limited. For more information on these policies, including how to update them, see https://docs.github.com/articles/restricting-access-to-your-organization-s-data/"
        #expect(graphqlError([real], data: nil).asGitHubError?.restrictedOrganizations ?? [] == ["acme"])
    }

    @Test func survivesRewordingOfTheSentenceAroundTheOrg() {
        let reworded = [
            "The `acme` organization has OAuth App access restrictions enabled.",
            "`acme` organization restricts data access to third-party applications.",
            "the `acme`  organization has enabled OAuth App access restrictions",
        ]
        for message in reworded {
            #expect(graphqlError([message], data: nil).asGitHubError?.restrictedOrganizations ?? [] == ["acme"], "\(message)")
            #expect(graphqlError([message], data: nil).asGitHubError?.isOnlyRestriction == true, "\(message)")
        }
    }

    @Test func ignoresAnOrgNamedInAnErrorThatIsNotARestriction() {
        #expect(
            (graphqlError(["The `acme` organization could not be found."], data: nil).asGitHubError?.restrictedOrganizations ?? []).isEmpty)
    }

    @Test func doesNotPairAnOrgInOneEntryWithARestrictionMarkerInAnother() {
        let error = graphqlError(
            [
                "The `acme` organization could not be found.",
                "Resource protected by access restrictions.",
            ], data: nil)
        #expect((error.asGitHubError?.restrictedOrganizations ?? []).isEmpty)
        #expect(error.asGitHubError?.isOnlyRestriction != true)
    }
}

@Suite struct IsOnlyRestrictionTests {
    @Test func isTrueWhenEveryReportedErrorIsARestriction() {
        #expect((graphqlError([restrictionMessage("status-im")], data: nil).asGitHubError?.isOnlyRestriction ?? false))
    }

    @Test func isFalseWhenSomethingElseFailedInTheSameResponse() {
        let error = graphqlError(
            [
                "the `status-im` organization has enabled OAuth App access restrictions",
                "Something went wrong while executing your query.",
            ], data: searchResult([]))
        #expect(error.asGitHubError?.isOnlyRestriction != true)
    }

    @Test func isTrueForThePlain403ShapeWhichCarriesNoErrorsToWalk() {
        #expect((httpError(403, restrictionMessage("status-im")).asGitHubError?.isOnlyRestriction ?? false))
    }

    @Test func isFalseForAnUnrelatedFailure() {
        #expect(GitHubError.network("network down").asGitHubError?.isOnlyRestriction != true)
        #expect(TestError("network down").asGitHubError?.isOnlyRestriction != true)
        #expect(graphqlError([], data: nil).asGitHubError?.isOnlyRestriction != true)
    }
}

@Suite struct GraphQLPartialDataTests {
    @Test func returnsThePayloadAPartialGraphQLErrorCarried() {
        let data = searchResult(["PR_1"])
        #expect(decodeJSON(graphqlError([restrictionMessage("status-im")], data: data).asGitHubError?.partialData) == data)
    }

    @Test func isNilForAnythingThatIsNotAGraphQLResponseError() {
        #expect(GitHubError.network("network down").asGitHubError?.partialData == nil)
        #expect(TestError("network down").asGitHubError?.partialData == nil)
    }
}

@Suite struct FormatRestrictedOrgsTests {
    @Test func isNilWhenNothingWasRestricted() {
        #expect(formatRestrictedOrgs([]) == nil)
    }

    @Test func namesOneOrg() {
        #expect(formatRestrictedOrgs(["status-im"]) == "status-im hasn't approved PullJoy")
    }

    @Test func namesTwoOrgs() {
        #expect(formatRestrictedOrgs(["acme", "status-im"]) == "acme and status-im haven't approved PullJoy")
    }

    @Test func namesThreeOrgsWithoutDroppingTheLast() {
        #expect(formatRestrictedOrgs(["acme", "beta", "status-im"]) == "acme, beta and status-im haven't approved PullJoy")
    }
}

@Suite struct MergeOrgsTests {
    @Test func isEmptyWhenThereIsNothingToMerge() {
        #expect(mergeOrgs().isEmpty)
        #expect(mergeOrgs([], []).isEmpty)
    }

    @Test func deduplicatesAcrossListsAndSortsSoTheWarningCopyIsStable() {
        #expect(mergeOrgs(["status-im"], ["acme", "status-im"], ["beta"]) == ["acme", "beta", "status-im"])
    }
}

@Suite struct IsTransientErrorTests {
    @Test(arguments: [500, 502, 503, 504])
    func matchesGitHubOrItsGatewayFailingOnItsOwnSide(status: Int) {
        #expect(httpError(status).asGitHubError?.isTransient == true)
    }

    @Test func matchesANetworkFailure() {
        #expect(GitHubError.network("The network connection was lost.").asGitHubError?.isTransient == true)
    }

    @Test(arguments: [401, 403, 429, 404])
    func doesNotMatchADeadTokenOrARateLimitWhichNeverAnswerDifferently(status: Int) {
        #expect(httpError(status).asGitHubError?.isTransient != true)
    }

    @Test func doesNotMatchAGraphQLErrorWhoseQueryWasAnswered() {
        #expect(unrelatedGraphQLError.asGitHubError?.isTransient != true)
    }

    @Test func doesNotMatchAStatusOutsideThe5xxRangeAtAll() {
        #expect(httpError(600).asGitHubError?.isTransient != true)
        #expect(httpError(0).asGitHubError?.isTransient != true)
    }

    @Test func doesNotMatchAMalformedAnswerOrAnErrorFromElsewhere() {
        #expect(GitHubError.malformed("no data").asGitHubError?.isTransient != true)
        #expect(TestError("network down").asGitHubError?.isTransient != true)
    }
}

@Suite struct IsAuthErrorTests {
    @Test func matchesA401() {
        #expect(httpError(401, "Bad credentials").asGitHubError?.isAuth == true)
    }

    @Test func doesNotMatchADifferentStatusLikeARateLimitOrServerError() {
        #expect(httpError(403, "API rate limit exceeded").asGitHubError?.isAuth != true)
        #expect(httpError(502, "Server Error").asGitHubError?.isAuth != true)
    }

    @Test func doesNotMatchAGraphQLErrorWhichCarriesNoStatus() {
        #expect(unrelatedGraphQLError.asGitHubError?.isAuth != true)
    }

    @Test func doesNotMatchAPlainNetworkFailure() {
        #expect(GitHubError.network("fetch failed").asGitHubError?.isAuth != true)
        #expect(TestError("Bad credentials").asGitHubError?.isAuth != true)
    }
}

@Suite struct InterpretResponseTests {
    private func body(_ json: String) -> Data { Data(json.utf8) }

    @Test func turnsANon2xxJSONAnswerIntoAnHTTPErrorWithItsMessageAndLowercasedHeaders() {
        #expect(throws: GitHubError.http(status: 401, message: "Bad credentials", headers: ["x-ratelimit-remaining": "0"])) {
            try URLSessionGraphQLClient.interpret(
                status: 401,
                headers: ["X-RateLimit-Remaining": "0"],
                body: body(#"{"message":"Bad credentials","documentation_url":"https://docs.github.com"}"#)
            )
        }
    }

    @Test func keepsANon2xxHTMLBodyAsTheMessageForDescribeErrorToReplace() {
        let error = #expect(throws: GitHubError.self) {
            try URLSessionGraphQLClient.interpret(status: 502, headers: [:], body: body(badGatewayPage))
        }
        #expect(error == .http(status: 502, message: badGatewayPage, headers: [:]))
        #expect(error.map(describeError) == "Couldn't reach GitHub — HTTP 502")
    }

    @Test func turnsA200WithErrorsIntoAGraphQLErrorCarryingThePartialData() {
        let error = #expect(throws: GitHubError.self) {
            try URLSessionGraphQLClient.interpret(
                status: 200, headers: [:],
                body: body(
                    """
                    {"data":{"search":{"nodes":[{"id":"PR_1"}]}},"errors":[{"message":"one"},{"message":"two"}]}
                    """))
        }
        guard case .graphql(let messages, let partialData)? = error else {
            Issue.record("expected a GraphQL error, got \(String(describing: error))")
            return
        }
        #expect(messages == ["one", "two"])
        #expect(decodeJSON(partialData) == searchResult(["PR_1"]))
    }

    @Test func carriesNoPartialDataWhenTheErrorsCameWithANullPayload() {
        #expect(throws: GitHubError.graphql(messages: ["nope"], partialData: nil)) {
            try URLSessionGraphQLClient.interpret(status: 200, headers: [:], body: body(#"{"data":null,"errors":[{"message":"nope"}]}"#))
        }
    }

    @Test func returnsTheDataOfA200() throws {
        let data = try URLSessionGraphQLClient.interpret(status: 200, headers: [:], body: body(#"{"data":{"viewer":{"login":"vlad"}}}"#))
        #expect(decodeJSON(data) == ["viewer": ["login": "vlad"]])
    }

    @Test func refusesA200ThatIsNotJSONOrCarriesNoData() {
        #expect(throws: GitHubError.malformed("GitHub answered with something that isn't JSON")) {
            try URLSessionGraphQLClient.interpret(status: 200, headers: [:], body: body("<html></html>"))
        }
        #expect(throws: GitHubError.malformed("GitHub answered without any data")) {
            try URLSessionGraphQLClient.interpret(status: 200, headers: [:], body: body(#"{"data":null}"#))
        }
    }
}

@Suite struct IsMissingScopeTests {
    @Test func recognisesGitHubRefusingATokenForLackOfAScope() {
        let message =
            "Your token has not been granted the required scopes to execute this query. The 'updateSubscription' field requires one of the following scopes: ['notifications']"
        #expect(graphqlError([message], data: nil).isMissingScope)
    }

    @Test func doesNotMistakeOtherFailuresForIt() {
        #expect(!graphqlError(["Could not resolve to a node"], data: nil).isMissingScope)
        #expect(!GitHubError.network("offline").isMissingScope)
    }
}
