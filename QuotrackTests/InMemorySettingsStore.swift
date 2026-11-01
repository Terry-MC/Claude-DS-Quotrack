import Foundation

/// A thread-safe SettingsStore for tests. It keeps settings in memory, so no
/// test ever reads or writes the real Application Support directory.
final class InMemorySettingsStore: SettingsStore, @unchecked Sendable {
    private let lock = NSLock()
    private var settings: AppSettings
    private(set) var saveCallCount = 0
    var saveError: (any Error)?

    init(settings: AppSettings = AppSettings()) {
        self.settings = settings
    }

    func loadSettings() -> AppSettings {
        lock.withLock { settings }
    }

    func saveSettings(_ settings: AppSettings) throws {
        if let saveError {
            throw saveError
        }
        lock.withLock {
            saveCallCount += 1
            self.settings = settings
        }
    }
}
