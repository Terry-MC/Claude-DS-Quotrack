import Testing

/// Provider collapse is panel state keyed by Provider identity, so it
/// survives the row updates that arrive while polling.
struct ProviderCollapseStateTests {
    @Test
    func everyProviderStartsExpanded() {
        let state = ProviderCollapseState()

        #expect(!state.isCollapsed(.deepSeek))
        #expect(!state.isCollapsed(.moonshot))
        #expect(!state.isCollapsed(.openRouter))
    }

    @Test
    func togglingCollapsesAndExpandsTheSameProvider() {
        var state = ProviderCollapseState()

        state.toggle(.moonshot)
        #expect(state.isCollapsed(.moonshot))
        #expect(!state.isCollapsed(.deepSeek))

        state.toggle(.moonshot)
        #expect(!state.isCollapsed(.moonshot))
    }

    @Test
    func eachProviderCollapsesIndependently() {
        var state = ProviderCollapseState()

        state.toggle(.deepSeek)
        state.toggle(.openRouter)

        #expect(state.isCollapsed(.deepSeek))
        #expect(!state.isCollapsed(.moonshot))
        #expect(state.isCollapsed(.openRouter))
    }
}
