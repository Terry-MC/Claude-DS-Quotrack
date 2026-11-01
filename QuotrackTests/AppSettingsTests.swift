import Foundation
import Testing

struct AppSettingsTests {
    @Test
    func defaultSettingsPollEveryFiveMinutes() {
        let settings = AppSettings()

        #expect(settings.pollingIntervalMinutes == 5)
        #expect(settings.pollingInterval == 300)
    }

    @Test
    func pollingIntervalIsClampedToOneThroughSixtyMinutes() {
        #expect(AppSettings(pollingIntervalMinutes: 0).pollingIntervalMinutes == 1)
        #expect(AppSettings(pollingIntervalMinutes: -10).pollingIntervalMinutes == 1)
        #expect(AppSettings(pollingIntervalMinutes: 1).pollingIntervalMinutes == 1)
        #expect(AppSettings(pollingIntervalMinutes: 60).pollingIntervalMinutes == 60)
        #expect(AppSettings(pollingIntervalMinutes: 61).pollingIntervalMinutes == 60)
        #expect(AppSettings(pollingIntervalMinutes: 1_000).pollingIntervalMinutes == 60)
    }
}
