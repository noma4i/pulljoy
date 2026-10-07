import PullJoyCore
import SwiftUI

struct InlineLink: View {
    var title: String
    var destination: URL
    @State private var hovering = false

    var body: some View {
        Link(title, destination: destination)
            .underline(hovering)
            .onHover { hovering = $0 }
            .linkCursor()
    }
}
