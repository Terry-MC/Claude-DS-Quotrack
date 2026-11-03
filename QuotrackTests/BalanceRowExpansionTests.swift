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

    @Test
    func expandOpensARowWithoutClosingOtherExpandedRows() {
        let first = UUID()
        let second = UUID()
        var expansion = BalanceRowExpansion()

        expansion.expand(first)
        expansion.expand(second)
        #expect(expansion.isExpanded(first))
        #expect(expansion.isExpanded(second))

        // Expanding an already expanded row is idempotent; focus must not
        // collapse the row a notification points at.
        expansion.expand(first)
        #expect(expansion.isExpanded(first))
    }
}
