import PullJoyCore
import PullJoyKit
import SwiftUI

struct SettingsView: View {
    @Bindable var model: AppModel

    var body: some View {
        switch model.settingsPane {
        case .root: root
        case .repositories: RepositoriesPane(model: model)
        }
    }

    private var root: some View {
        let settings = model.settings
        let snapshot = model.snapshot

        return VStack(spacing: 0) {
            PaneHeader(back: "Inbox", title: "Settings") { model.showSettings = false }
            Divider()

            ScrollView {
                VStack(spacing: 12) {
                    SettingsGroup {
                        SettingRow(
                            label: "Repositories",
                            value: repositorySummary(
                                watchAll: settings.watchAllRepositories,
                                known: snapshot.knownRepositories,
                                selected: settings.repositories
                            ),
                            onTap: { model.settingsPane = .repositories }
                        )
                    }

                    SettingsGroup {
                        SettingRow(label: "Refresh every") {
                            Picker("Refresh every", selection: binding(\.pollIntervalMinutes)) {
                                ForEach(Preferences.pollIntervalOptions, id: \.self) { Text(verbatim: "\($0) min").tag($0) }
                            }
                        }
                        Divider().padding(.leading, 12)
                        SettingRow(label: "Appearance") {
                            Picker("Appearance", selection: binding(\.theme)) {
                                ForEach(ThemePreference.allCases, id: \.self) { Text($0.label).tag($0) }
                            }
                        }
                        Divider().padding(.leading, 12)
                        SettingRow(label: "Layout") {
                            Picker("Layout", selection: binding(\.layout)) {
                                ForEach(Layout.allCases, id: \.self) { Text($0.label).tag($0) }
                            }
                        }
                        Divider().padding(.leading, 12)
                        SettingRow(
                            label: "Open with a shortcut",
                            problem: settings.globalShortcut != nil && !model.shortcutActive
                                ? "Another app already uses this shortcut — pick a different one."
                                : nil
                        ) {
                            Picker("Open with a shortcut", selection: binding(\.globalShortcut)) {
                                Text("Off").tag(GlobalShortcut?.none)
                                ForEach(GlobalShortcut.allCases, id: \.self) { Text($0.label).tag(GlobalShortcut?.some($0)) }
                            }
                        }
                        Divider().padding(.leading, 12)
                        SettingRow(
                            label: "Start at login",
                            description: "PullJoy is a menu-bar app — it opens nothing on screen.",
                            problem: model.launchAtLogin == .requiresApproval
                                ? "macOS is waiting for you to allow PullJoy in Login Items."
                                : nil
                        ) {
                            if model.launchAtLogin == .requiresApproval {
                                Button("Open Login Items") { LoginItem.openSystemSettings() }
                                    .controlSize(.small)
                            }
                            Toggle(
                                "Start at login",
                                isOn: Binding(
                                    get: { model.launchAtLogin != .off },
                                    set: { model.setLaunchAtLogin($0) }
                                )
                            )
                            .toggleStyle(.switch)
                            .controlSize(.small)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()

                    SettingsGroup {
                        McpSection(model: model)
                    }

                    AccountRow(model: model)
                }
                .padding(12)
            }

            Divider()
            footer
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 0) {
                Text(verbatim: "PullJoy \(AppConfig.version) · MIT · ")
                InlineLink(title: "Source", destination: AppConfig.sourceURL)
            }
            HStack(spacing: 0) {
                Text("Idea from ")
                InlineLink(title: "Pullover", destination: AppConfig.originalURL)
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .tint(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Metrics.raised)
    }

    private func binding<T>(_ keyPath: WritableKeyPath<Preferences, T>) -> Binding<T> {
        Binding(
            get: { model.settings[keyPath: keyPath] },
            set: { value in model.updateSettings { $0[keyPath: keyPath] = value } }
        )
    }
}
