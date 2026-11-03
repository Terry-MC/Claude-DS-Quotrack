import Foundation
import Testing

/// Clicking a notification must reveal the first affected Account even when
/// the same Account was focused by an earlier notification. A generation
/// counter lets the view react to repeated requests for the same identity.
@MainActor
struct PanelFocusModelTests {
    @Test
    func aFocusRequestCarriesTheAccountAndStartsAtOne() throws {
        let model = PanelFocusModel()
        let accountID = UUID()

        #expect(model.request == nil)
        model.focus(accountID)

        let request = try #require(model.request)
        #expect(request.accountID == accountID)
        #expect(request.sequence == 1)
    }

    @Test
    func refocusingTheSameAccountStillAdvancesTheSequence() throws {
        let model = PanelFocusModel()
        let accountID = UUID()

        model.focus(accountID)
        model.focus(accountID)
        model.focus(accountID)

        let request = try #require(model.request)
        #expect(request.accountID == accountID)
        #expect(request.sequence == 3)
    }
}
