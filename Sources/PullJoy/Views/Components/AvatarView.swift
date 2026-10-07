import PullJoyCore
import SwiftUI

struct AvatarView: View {
    var login: String
    var urlString: String
    var size: CGFloat

    var body: some View {
        ZStack {
            if let image = sizedURL.flatMap({ AvatarCache.shared.image(for: $0) }) {
                Image(nsImage: image).resizable().scaledToFill()
            } else {
                ZStack {
                    Accent.primary.tint
                    Text(initials(of: login))
                        .font(.system(size: size * 0.36, weight: .semibold))
                        .foregroundStyle(Color.link)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(Metrics.hairline, lineWidth: 0.5))
    }

    /// GitHub serves avatars at any size; ask for the one drawn, at 2x.
    private var sizedURL: URL? {
        guard !urlString.isEmpty, var components = URLComponents(string: urlString) else { return nil }
        var query = components.queryItems ?? []
        query.removeAll { $0.name == "s" }
        query.append(URLQueryItem(name: "s", value: String(Int(size * 2))))
        components.queryItems = query
        return components.url
    }
}
