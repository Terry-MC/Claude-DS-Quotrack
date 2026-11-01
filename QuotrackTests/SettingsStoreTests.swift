import Foundation
import Testing

struct SettingsStoreTests {
    @Test
    func settingsRoundTripAcrossRelaunch() throws {
        let directory = try makeTemporarySettingsDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = FileSettingsStore(directoryURL: directory)
        try store.saveSettings(AppSettings(pollingIntervalMinutes: 17))

        let relaunched = FileSettingsStore(directoryURL: directory)

        #expect(relaunched.loadSettings() == AppSettings(pollingIntervalMinutes: 17))
    }

    @Test
    func missingSettingsFileLoadsDefaults() throws {
        let directory = try makeTemporarySettingsDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = FileSettingsStore(directoryURL: directory)

        #expect(store.loadSettings() == AppSettings())
    }

    @Test
    func corruptSettingsFileLoadsDefaultsWithoutCrashing() throws {
        let directory = try makeTemporarySettingsDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = FileSettingsStore(directoryURL: directory)
        try store.saveSettings(AppSettings(pollingIntervalMinutes: 12))
        try Data("{\"pollingIntervalMinutes\":".utf8).write(
            to: directory.appendingPathComponent("settings.json")
        )

        #expect(store.loadSettings() == AppSettings())
    }

    @Test
    func outOfRangePersistedIntervalsAreClampedOnLoad() throws {
        let directory = try makeTemporarySettingsDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("settings.json")

        try Data("{\"pollingIntervalMinutes\":0}".utf8).write(to: file)
        #expect(FileSettingsStore(directoryURL: directory).loadSettings().pollingIntervalMinutes == 1)

        try Data("{\"pollingIntervalMinutes\":999}".utf8).write(to: file)
        #expect(FileSettingsStore(directoryURL: directory).loadSettings().pollingIntervalMinutes == 60)
    }
}

private func makeTemporarySettingsDirectory() throws -> URL {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("QuotrackSettingsTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
}
