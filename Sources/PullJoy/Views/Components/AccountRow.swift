import PullJoyCore
import SwiftUI

struct AccountRow: View {
    var model: AppModel

    var body: some View {
        let login = model.snapshot.myLogin
        HStack(spacing: 12) {
            // `myLogin` lands with the first fetch; the glyph stands in until then.
            ZStack {
                Circle().fill(Accent.primary.tint)
                if let login {
                    Text(initials(of: login)).font(.system(size: 14, weight: .semibold)).foregroundStyle(Color.link)
                } else {
                    Image(systemName: "person.fill").foregroundStyle(Color.link)
                }
            }
            .frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 1) {
                Text(login ?? "Signed in").font(.system(size: 13, weight: .semibold)).lineLimit(1)
                Text("Signed in with GitHub").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button("Sign out", role: .destructive) { model.signOut() }
                .buttonStyle(.borderless)
                .foregroundStyle(Color.deletions)
        }
        .padding(.horizontal, 4)
    }
}
