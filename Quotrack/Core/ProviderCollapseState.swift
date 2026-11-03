import Foundation

/// Which Provider cards are collapsed. Keyed by Provider identity so collapse
/// survives the Snapshot and Account updates that arrive while polling.
struct ProviderCollapseState: Equatable, Sendable {
    private(set) var collapsedProviders: Set<Provider> = []

    func isCollapsed(_ provider: Provider) -> Bool {
        collapsedProviders.contains(provider)
    }

    mutating func toggle(_ provider: Provider) {
        if collapsedProviders.contains(provider) {
            collapsedProviders.remove(provider)
        } else {
            collapsedProviders.insert(provider)
        }
    }

    /// Reveals a Provider card, used when a notification or toast focuses an
    /// Account that sits inside it.
    mutating func expand(_ provider: Provider) {
        collapsedProviders.remove(provider)
    }
}
