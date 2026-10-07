import Foundation

/// Union of org names, deduplicated and sorted so the warning copy is stable.
public func mergeOrgs(_ lists: [String]...) -> [String] {
    mergeOrgs(lists)
}

public func mergeOrgs(_ lists: [[String]]) -> [String] {
    Array(Set(lists.flatMap { $0 })).sorted()
}

public func formatRestrictedOrgs(_ orgs: [String]) -> String? {
    switch orgs.count {
    case 0: nil
    case 1: "\(orgs[0]) hasn't approved PullJoy"
    case 2: "\(orgs[0]) and \(orgs[1]) haven't approved PullJoy"
    default: "\(orgs.dropLast().joined(separator: ", ")) and \(orgs[orgs.endIndex - 1]) haven't approved PullJoy"
    }
}
