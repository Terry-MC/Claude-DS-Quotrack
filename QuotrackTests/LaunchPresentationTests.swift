import Testing

struct LaunchPresentationTests {
    @Test
    func mockModeSkipsOnboardingAndShowsThePanel() {
        let presentation = LaunchPresentation.make(mode: .mock, storedAccountCount: 0)

        #expect(presentation.showsOnboarding == false)
        #expect(presentation.showsPanel == true)
    }

    @Test
    func emptyLiveInstallShowsOnboarding() {
        let presentation = LaunchPresentation.make(mode: .live, storedAccountCount: 0)

        #expect(presentation.showsOnboarding == true)
        #expect(presentation.showsPanel == false)
    }

    @Test
    func liveInstallWithStoredAccountsSkipsOnboarding() {
        let presentation = LaunchPresentation.make(mode: .live, storedAccountCount: 2)

        #expect(presentation.showsOnboarding == false)
        #expect(presentation.showsPanel == false)
    }
}
