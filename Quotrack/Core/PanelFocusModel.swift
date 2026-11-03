import Foundation
import Observation

/// A request to reveal and expand one Account row. The sequence makes repeated
/// requests for the same Account observable, so a second notification for that
/// Account still scrolls the panel back to it.
@MainActor
@Observable
final class PanelFocusModel {
    struct Request: Equatable, Sendable {
        let accountID: Account.ID
        let sequence: Int
    }

    private(set) var request: Request?
    @ObservationIgnored private var sequence = 0

    func focus(_ accountID: Account.ID) {
        sequence += 1
        request = Request(accountID: accountID, sequence: sequence)
    }
}
