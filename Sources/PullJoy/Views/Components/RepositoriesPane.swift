import PullJoyCore
import SwiftUI

struct RepositoriesPane: View {
    @Bindable var model: AppModel
    @State private var filter = ""

    var body: some View {
        let settings = model.settings
        let options = repositoryOptions(known: model.snapshot.knownRepositories, selected: settings.repositories)
        let needle = filter.trimmingCharacters(in: .whitespaces).lowercased()
        let visible = needle.isEmpty ? options : options.filter { $0.lowercased().contains(needle) }
        // Folded like the store folds them: an older build may have saved mixed case.
        let ticked = Set(settings.repositories.map { $0.lowercased() })
        let selectedCount = tickedRepositoryCount(known: model.snapshot.knownRepositories, selected: settings.repositories)

        VStack(spacing: 0) {
            PaneHeader(back: "Settings", title: "Repositories") { model.settingsPane = .root }
            Divider()

            VStack(alignment: .leading, spacing: 12) {
                SettingsGroup {
                    SettingRow(label: "Watch all", description: "Every repository you are involved in, now and later.") {
                        Toggle(
                            "Watch all repositories",
                            isOn: Binding(
                                get: { settings.watchAllRepositories },
                                set: { value in model.updateSettings { $0.watchAllRepositories = value } }
                            )
                        )
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .labelsHidden()
                    }
                }

                // Nothing to narrow while every repository is watched.
                if !settings.watchAllRepositories {
                    if options.isEmpty {
                        Text("Nothing in your inbox yet, so there's nothing to narrow.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        SettingsGroup {
                            HStack(spacing: 6) {
                                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                                TextField("Filter repositories", text: $filter)
                                    .textFieldStyle(.plain)
                                Text(verbatim: "\(selectedCount)/\(options.count)")
                                    .font(.caption)
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                            .padding(10)
                            Divider()
                            ScrollView {
                                VStack(alignment: .leading, spacing: 8) {
                                    if visible.isEmpty {
                                        Text(verbatim: "No repository matches “\(filter.trimmingCharacters(in: .whitespaces))”.")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    ForEach(visible, id: \.self) { repo in
                                        Toggle(
                                            isOn: Binding(
                                                get: { ticked.contains(repo.lowercased()) },
                                                set: { model.setRepository(repo, watched: $0) }
                                            )
                                        ) {
                                            RepositoryName(fullName: repo)
                                        }
                                        .toggleStyle(.checkbox)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(10)
                            }
                        }
                        .frame(maxHeight: .infinity, alignment: .top)

                        if let error = model.repositoryError {
                            Text(error).font(.caption).foregroundStyle(Color.deletions)
                        }
                        if selectedCount == 0 {
                            Text("Nothing ticked, so nothing shows. Tick the repos you care about.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(12)
        }
    }
}

/// The owner is the same for most rows, so it recedes and the repo name carries the row.
struct RepositoryName: View {
    var fullName: String

    var body: some View {
        if let slash = fullName.firstIndex(of: "/") {
            Text(fullName[...slash]).foregroundStyle(.secondary) + Text(fullName[fullName.index(after: slash)...])
        } else {
            Text(fullName)
        }
    }
}
