import PullJoyCore
import SwiftUI

struct PRMenuItems: View {
    var model: AppModel
    var item: ClassifiedPullRequest

    var body: some View {
        ForEach(Array(prMenuEntries(isSnoozed: item.isSnoozed).enumerated()), id: \.offset) { _, entry in
            switch entry {
            case .separator:
                Divider()
            case .item(let label, let action):
                Button(label) { model.perform(action, on: item) }
            }
        }
    }
}
