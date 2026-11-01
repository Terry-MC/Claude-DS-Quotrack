/// What a launch should present, derived from the data source and the stored
/// Account list. Mock mode has fixture Accounts, so it goes straight to the
/// panel; an empty live install shows onboarding instead.
struct LaunchPresentation: Equatable, Sendable {
    let showsOnboarding: Bool
    let showsPanel: Bool

    static func make(mode: DataSourceMode, storedAccountCount: Int) -> LaunchPresentation {
        switch mode {
        case .mock:
            return LaunchPresentation(showsOnboarding: false, showsPanel: true)
        case .live:
            return LaunchPresentation(
                showsOnboarding: storedAccountCount == 0,
                showsPanel: false
            )
        }
    }
}
