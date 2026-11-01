/// The data source the app reads Accounts and Balances from. The monitor, UI,
/// and refresh behavior are identical in both modes.
enum DataSourceMode: String, Sendable, Equatable, CaseIterable {
    case live
    case mock

    var toggled: DataSourceMode {
        self == .live ? .mock : .live
    }
}

/// Process launch arguments that select the data source.
struct LaunchOptions: Equatable, Sendable {
    let dataSourceMode: DataSourceMode

    static func parse(arguments: [String]) -> LaunchOptions {
        LaunchOptions(
            dataSourceMode: arguments.contains("--mock") ? .mock : .live
        )
    }
}
