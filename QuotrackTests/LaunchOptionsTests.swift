import Testing

struct LaunchOptionsTests {
    @Test(arguments: [
        (["Quotrack"], DataSourceMode.live),
        (["Quotrack", "--mock"], DataSourceMode.mock),
        (["Quotrack", "--verbose", "--mock"], DataSourceMode.mock),
    ])
    func parsesTheMockLaunchArgument(arguments: [String], expected: DataSourceMode) {
        #expect(LaunchOptions.parse(arguments: arguments).dataSourceMode == expected)
    }
}
