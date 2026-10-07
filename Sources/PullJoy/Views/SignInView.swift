import SwiftUI

struct SignInView: View {
    var model: AppModel

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.triangle.pull")
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(Color.link)
            Text("PullJoy")
                .font(.system(size: 20, weight: .bold))

            Text(
                model.signIn == .idle
                    ? "Sign in with GitHub to see what needs you."
                    : "Finish signing in in your browser."
            )
            .font(.callout)
            .foregroundStyle(.secondary)

            if model.signIn == .idle {
                Button {
                    model.startSignIn()
                } label: {
                    Label("Sign in with GitHub", systemImage: "person.crop.circle.badge.checkmark")
                        .padding(.horizontal, 6)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            } else {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Waiting for GitHub…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Button("Cancel") { model.cancelSignIn() }
                    .buttonStyle(.borderless)
            }

            // Signed out in the app, but the token may still be in the Keychain
            // and would sign the next launch back in.
            if let error = model.signOutError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(Color.deletions)
            }
            if let error = model.signInError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(Color.deletions)
            }
        }
        .multilineTextAlignment(.center)
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
