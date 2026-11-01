import Foundation
import Testing

struct BalanceRowExpansionTests {
    @Test
    func rowsStartCollapsedAndToggleOpenAndClosed() {
        let accountID = UUID()
        var expansion = BalanceRowExpansion()

        #expect(!expansion.isExpanded(accountID))

        expansion.toggle(accountID)
        #expect(expansion.isExpanded(accountID))

        expansion.toggle(accountID)
        #expect(!expansion.isExpanded(accountID))
    }

    @Test
    func expandingOneRowLeavesTheOtherRowsCollapsed() {
        let first = UUID()
        let second = UUID()
        var expansion = BalanceRowExpansion()

        expansion.toggle(first)
        #expect(expansion.isExpanded(first))
        #expect(!expansion.isExpanded(second))

        expansion.toggle(second)
        expansion.toggle(first)
        #expect(!expansion.isExpanded(first))
        #expect(expansion.isExpanded(second))
    }
}
