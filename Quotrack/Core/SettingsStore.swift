import Foundation

/// The persistence seam for app-wide preferences. Tests and previews use an
/// in-memory implementation; the app uses `FileSettingsStore`.
protocol SettingsStore: Sendable {
    func loadSettings() -> AppSettings
    func saveSettings(_ settings: AppSettings) throws
}

/// Persists app-wide preferences as JSON next to Account metadata. Writes are
/// atomic, and a missing or unreadable file loads as defaults rather than
/// failing app launch.
struct FileSettingsStore: SettingsStore {
    private enum FileName {
        static let settings = "settings.json"
    }

    let directoryURL: URL

    init(directoryURL: URL) {
        self.directoryURL = directoryURL
    }

    func loadSettings() -> AppSettings {
        guard
            let data = try? Data(contentsOf: directoryURL.appendingPathComponent(FileName.settings)),
            let settings = try? JSONDecoder().decode(AppSettings.self, from: data)
        else {
            return AppSettings()
        }
        return settings
    }

    func saveSettings(_ settings: AppSettings) throws {
        let data = try JSONEncoder().encode(settings)
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        try data.write(
            to: directoryURL.appendingPathComponent(FileName.settings),
            options: .atomic
        )
    }
}
