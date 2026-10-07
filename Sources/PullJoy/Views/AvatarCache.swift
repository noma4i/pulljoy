import AppKit
import Observation

/// Author avatars, fetched once per URL and kept for the life of the app.
/// `AsyncImage` refetches whenever a row is recreated, and gives no way to
/// know when it has finished — which the snapshot renderer needs.
@MainActor
@Observable
final class AvatarCache {
    static let shared = AvatarCache()
    private static let retryAfter: TimeInterval = 60

    private(set) var images: [URL: NSImage] = [:]
    @ObservationIgnored private var loading: Set<URL> = []
    @ObservationIgnored private var failedAt: [URL: Date] = [:]

    var isIdle: Bool { loading.isEmpty }

    /// The image if it has arrived; otherwise starts fetching it and returns nil.
    func image(for url: URL) -> NSImage? {
        if let image = images[url] { return image }
        guard !loading.contains(url) else { return nil }
        if let at = failedAt[url], Date().timeIntervalSince(at) < Self.retryAfter { return nil }
        loading.insert(url)
        Task {
            let data = try? await URLSession.shared.data(from: url).0
            loading.remove(url)
            if let data, let image = NSImage(data: data) {
                images[url] = image
                failedAt[url] = nil
            } else {
                failedAt[url] = Date()
            }
        }
        return nil
    }
}
