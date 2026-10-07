import PullJoyCore
import SwiftUI

struct RootView: View {
    @Bindable var model: AppModel

    static let size = CGSize(width: 440, height: 620)

    var body: some View {
        // One frame for every state, so the popup's silhouette never changes
        // when signing in or opening settings.
        VStack(spacing: 0) {
            content
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(alignment: .bottom) {
            if let toast = model.toast, !model.showSettings {
                ToastView(toast: toast) { model.toastAction() }
                    .padding(.bottom, 56)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.15), value: model.toast)
    }

    @ViewBuilder
    private var content: some View {
        let snapshot = model.snapshot
        if snapshot.status == .signedOut {
            SignInView(model: model)
        } else if model.showSettings {
            SettingsView(model: model)
        } else if snapshot.status == .loading && snapshot.items.isEmpty && snapshot.lastUpdatedAt == nil {
            ProgressView()
                .controlSize(.regular)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            HeaderView(model: model)
            Divider()
            InboxListView(model: model)
            Divider()
            HintsBar()
        }
    }
}
