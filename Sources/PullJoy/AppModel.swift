import AppKit
import Observation
import PullJoyCore
import PullJoyKit

enum SignInState: Equatable {
    case idle
    case waitingForBrowser
}

enum SettingsPane {
    case root, repositories
}

struct Toast: Equatable {
    enum Kind: Equatable {
        case snoozed
        case unsubscribed
        case failure(String)
        case needsPermission
        case hiddenOnly(String)
    }

    var kind: Kind
    var prId: String
    var number: Int

    var actionLabel: String? {
        switch kind {
        case .snoozed, .unsubscribed, .hiddenOnly: "Undo"
        case .needsPermission: "Sign in again"
        case .failure: nil
        }
    }
}

/// Owns the app's services and everything the popup shows. Views read from it
/// and call its actions; nothing below it knows about AppKit.
@MainActor
@Observable
final class AppModel {
    let inbox: Inbox
    let updater: UpdateChecker
    @ObservationIgnored let store: AppStore
    @ObservationIgnored private let tokenStore: any TokenStore
    @ObservationIgnored private let mcpServer: MCPServer
    @ObservationIgnored private let hotKey = HotKey()
    @ObservationIgnored private var signInTask: Task<Void, Never>?
    @ObservationIgnored private var toastTask: Task<Void, Never>?
    @ObservationIgnored private var subscriptionTail: Task<Void, Never>?
    @ObservationIgnored private var clockTask: Task<Void, Never>?

    /// Set by the popover controller.
    @ObservationIgnored var hidePopup: () -> Void = {}
    @ObservationIgnored var togglePopup: () -> Void = {}
    @ObservationIgnored var showRowMenu: (ClassifiedPullRequest, _ atPointer: Bool) -> Void = { _, _ in }
    @ObservationIgnored var onSettingsChange: (Preferences) -> Void = { _ in }

    private(set) var settings: Preferences
    var showSettings = false
    var settingsPane = SettingsPane.root
    var collapsed: Set<InboxSection> = [.waiting]
    private(set) var selectedID: String? {
        didSet {
            if let index = visibleItems.firstIndex(where: { $0.id == selectedID }) { selectedIndexHint = index }
        }
    }
    /// Where the cursor last sat, so it can stay in place when its row leaves.
    @ObservationIgnored private var selectedIndexHint = 0
    /// Bumped on a deliberate move — keys, a click — so the list scrolls to it.
    /// A hover moves the selection quietly and must not scroll under the pointer.
    private(set) var scrollRequest = 0
    private(set) var toast: Toast?
    /// Keeps the relative ages honest without re-fetching anything.
    private(set) var now = Date()
    private(set) var signIn = SignInState.idle
    private(set) var signInError: String?
    /// Set when sign-out could not remove the token from the Keychain.
    private(set) var signOutError: String?
    private(set) var launchAtLogin = LoginItem.status
    private(set) var shortcutActive = true
    private(set) var mcpStatus = MCPServerStatus.stopped
    var repositoryError: String?

    let mcpURLString = mcpURL(port: AppConfig.mcpPort)

    init() {
        let demo = DemoInbox.isEnabled
        let store = demo ? DemoInbox.makeStore() : AppStore(defaults: AppConfig.defaults)
        self.store = store
        self.settings = store.settings
        if demo {
            self.tokenStore = InMemoryTokenStore(token: "demo")
            self.inbox = DemoInbox.makeInbox(store: store)
        } else {
            self.tokenStore = KeychainTokenStore(service: AppConfig.appName)
            self.inbox = Inbox(store: store)
        }
        self.updater = UpdateChecker(repository: AppConfig.updateRepository ?? "", currentVersion: AppConfig.version)

        let tools = MCPTools(inbox: inbox, store: store, version: AppConfig.version)
        mcpServer = MCPServer { message in await tools.handle(message) }

        inbox.onAuthError = { [weak self] in self?.signOut() }
        // Live, not a copy taken after the switch: a listener can fail later.
        mcpServer.onStatusChange = { [weak self] status in self?.mcpStatus = status }
        hotKey.onTrigger = { [weak self] in self?.togglePopup() }
    }

    func launch() {
        if DemoInbox.isEnabled {
            inbox.client = DemoInbox.Client()
            inbox.start()
        } else if let token = tokenStore.load() {
            inbox.client = URLSessionGraphQLClient(token: token)
            inbox.start()
        }
        shortcutActive = hotKey.apply(settings.globalShortcut)
        Task { await applyMCPSetting() }
        if AppConfig.isPackaged, AppConfig.updateRepository != nil { updater.start() }
    }

    func willTerminate() {
        mcpServer.stop()
    }

    // MARK: - Popup lifecycle

    func popupWillOpen() {
        now = Date()
        clockTask?.cancel()
        clockTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                self?.now = Date()
            }
        }
        launchAtLogin = LoginItem.status
        shortcutActive = hotKey.isActive
        // Opening onto a stale list is the one moment worth spending a fetch on.
        if inbox.client != nil, inbox.snapshot.shouldRefreshOnOpen(now: now) {
            refresh()
        }
        ensureSelection()
        scrollRequest += 1
    }

    func popupDidClose() {
        clockTask?.cancel()
        clockTask = nil
    }

    // MARK: - Inbox

    var snapshot: InboxSnapshot { inbox.snapshot }

    /// Each section in the order it is drawn — stacks gathered into contiguous
    /// runs. Both the list and the keyboard cursor read from here, so they
    /// cannot disagree about where a row sits.
    var orderedSections: [(category: InboxSection, items: [ClassifiedPullRequest])] {
        InboxSection.visible.compactMap { category in
            let items = orderSection(snapshot.items.filter { $0.category == category })
            return items.isEmpty ? nil : (category, items)
        }
    }

    /// The order the keyboard cursor travels: visual order, skipping collapsed sections.
    var visibleItems: [ClassifiedPullRequest] {
        orderedSections.filter { !collapsed.contains($0.category) }.flatMap(\.items)
    }

    var selectedItem: ClassifiedPullRequest? {
        selectedID.flatMap { id in snapshot.items.first { $0.id == id } }
    }

    func refresh() {
        Task { await inbox.refresh() }
    }

    func toggleSection(_ category: InboxSection) {
        if collapsed.contains(category) { collapsed.remove(category) } else { collapsed.insert(category) }
        ensureSelection()
    }

    // MARK: - Selection

    func pointAt(_ id: String) {
        selectedID = id
    }

    func select(_ id: String) {
        selectedID = id
        scrollRequest += 1
    }

    /// Keeps the cursor on a row that is shown: the first one as soon as there
    /// is one, so the keys work the moment the popup opens, and the row now in
    /// its place when its own row leaves — snoozed into a collapsed section, or
    /// collapsed itself. The keys act on the cursor, so it must never sit on a
    /// hidden row.
    func ensureSelection() {
        let items = visibleItems
        guard !items.contains(where: { $0.id == selectedID }) else { return }
        selectedID = selectedID == nil || items.isEmpty ? items.first?.id : items[min(selectedIndexHint, items.count - 1)].id
    }

    func moveSelection(by delta: Int) {
        let items = visibleItems
        guard !items.isEmpty else { return }
        let next: Int
        if let current = items.firstIndex(where: { $0.id == selectedID }) {
            next = (current + delta + items.count) % items.count
        } else {
            next = delta > 0 ? 0 : items.count - 1
        }
        select(items[next].id)
    }

    // MARK: - Pull request actions

    func open(_ item: ClassifiedPullRequest) {
        select(item.id)
        openURL(item.pr.url)
    }

    func openURL(_ string: String) {
        guard isSafeExternalURL(string), let url = URL(string: string) else { return }
        NSWorkspace.shared.open(url)
    }

    func perform(_ action: PRMenuAction, on item: ClassifiedPullRequest) {
        let pr = item.pr
        switch action {
        case .open: openURL(pr.url)
        case .openFiles: openURL("\(pr.url)/files")
        case .copyLink: copy(pr.url)
        case .copyBranch: copy(pr.headRefName)
        case .snoozeUntilActivity: snooze(item, type: .untilActivity)
        case .snooze4Hours: snooze(item, type: .untilTime, hours: 4)
        case .snoozeUntilTomorrow: snooze(item, type: .untilTime, hours: 24)
        case .unsnooze: unsnooze(pr.id)
        case .unsubscribe: setSubscribed(false, id: pr.id, number: pr.number)
        }
    }

    private func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    func snooze(_ item: ClassifiedPullRequest, type: SnoozeType, hours: Int? = nil) {
        store.snooze(item.pr.id, type: type, now: Date(), hours: hours, headSHA: item.pr.headSHA)
        inbox.reclassify()
        showToast(.snoozed, id: item.pr.id, number: item.pr.number)
    }

    func unsnooze(_ prId: String) {
        store.unsnooze(prId)
        inbox.reclassify()
    }

    /// Hides the pull request at once and tells GitHub in the background; if GitHub refuses, it comes back.
    private func setSubscribed(_ subscribed: Bool, id: String, number: Int) {
        if subscribed { store.resubscribe(id) } else { store.unsubscribe(id) }
        inbox.reclassify()
        if !subscribed { showToast(.unsubscribed, id: id, number: number) }

        let previous = subscriptionTail
        subscriptionTail = Task { [weak self] in
            await previous?.value
            guard let self else { return }
            do {
                let result = try await inbox.setSubscribed(subscribed, prID: id)
                if case .refusedByOrganization(let organization) = result, !subscribed {
                    showToast(.hiddenOnly(organization), id: id, number: number)
                }
            } catch {
                if subscribed { store.unsubscribe(id) } else { store.resubscribe(id) }
                inbox.reclassify()
                let missingScope = error.asGitHubError?.isMissingScope == true
                showToast(missingScope ? .needsPermission : .failure(describeError(error)), id: id, number: number)
            }
        }
    }

    private func showToast(_ kind: Toast.Kind, id: String, number: Int) {
        toast = Toast(kind: kind, prId: id, number: number)
        toastTask?.cancel()
        toastTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(kind == .snoozed || kind == .unsubscribed ? 4 : 10))
            guard !Task.isCancelled else { return }
            self?.toast = nil
        }
    }

    func toastAction() {
        guard let toast else { return }
        switch toast.kind {
        case .needsPermission:
            signOut()
            startSignIn()
        default: undoToast()
        }
    }

    private func undoToast() {
        guard let toast else { return }
        switch toast.kind {
        case .snoozed: unsnooze(toast.prId)
        case .unsubscribed, .hiddenOnly: setSubscribed(true, id: toast.prId, number: toast.number)
        case .failure, .needsPermission: break
        }
        toastTask?.cancel()
        self.toast = nil
    }

    // MARK: - Settings

    func updateSettings(_ change: (inout Preferences) -> Void) {
        let before = settings
        store.updateSettings(change)
        settings = store.settings

        if settings.pollIntervalMinutes != before.pollIntervalMinutes, inbox.client != nil { inbox.start() }
        if settings.watchAllRepositories != before.watchAllRepositories { inbox.reclassify() }
        if settings.globalShortcut != before.globalShortcut { shortcutActive = hotKey.apply(settings.globalShortcut) }
        if settings.mcpServerEnabled != before.mcpServerEnabled { Task { await applyMCPSetting() } }
        onSettingsChange(settings)
    }

    func setRepository(_ fullName: String, watched: Bool) {
        repositoryError = nil
        do {
            if watched { try store.addRepository(fullName) } else { store.removeRepository(fullName) }
        } catch {
            repositoryError = error.localizedDescription
        }
        settings = store.settings
        inbox.reclassify()
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        launchAtLogin = LoginItem.setEnabled(enabled)
    }

    private func applyMCPSetting() async {
        if settings.mcpServerEnabled {
            await mcpServer.start(port: AppConfig.mcpPort)
        } else {
            mcpServer.stop()
        }
        mcpStatus = mcpServer.status
    }

    // MARK: - Account

    /// A second click while a sign-in runs does nothing: two listeners would race to save the token.
    func startSignIn() {
        guard signInTask == nil else { return }
        signInError = nil
        guard let app = AppConfig.githubOAuthApp else {
            signInError = "This build has no GitHub OAuth App. See the README."
            return
        }
        signIn = .waitingForBrowser
        signInTask = Task {
            defer {
                signInTask = nil
                signIn = .idle
            }
            do {
                let flow = BrowserSignIn(app: app) { url in DispatchQueue.main.async { NSWorkspace.shared.open(url) } }
                let token = try await flow.signIn()
                try tokenStore.save(token)
                inbox.client = URLSessionGraphQLClient(token: token)
                inbox.start()
            } catch is CancellationError {
                return
            } catch {
                signInError = error.localizedDescription
            }
        }
    }

    func cancelSignIn() {
        signInTask?.cancel()
    }

    func signOut() {
        signInTask?.cancel()
        // Signed out of this run either way; a failed delete is reported
        // because the token would load again at the next launch.
        do {
            try tokenStore.clear()
            signOutError = nil
        } catch {
            signOutError = error.localizedDescription
        }
        inbox.client = nil
        showSettings = false
        settingsPane = .root
        selectedID = nil
    }

    func installUpdate() {
        if let url = updater.state.url { NSWorkspace.shared.open(url) }
    }
}
