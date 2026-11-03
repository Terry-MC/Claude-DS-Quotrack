import Foundation
import Testing

/// The add-Account and onboarding pickers read this metadata, so hiding a
/// legacy Provider is a property of the Provider model rather than a view-only
/// filter. SiliconFlow stays in the enum so v1 JSON still decodes.
struct ProviderSupportTests {
    @Test
    func siliconFlowIsLegacyUnsupportedWhileTheV2ProvidersRemainSupported() {
        #expect(!Provider.siliconFlow.isSupported)
        #expect(Provider.siliconFlow.isLegacyUnsupported)

        #expect(Provider.deepSeek.isSupported)
        #expect(Provider.moonshot.isSupported)
        #expect(Provider.openRouter.isSupported)
        #expect(Provider.deepSeek.isLegacyUnsupported == false)
        #expect(Provider.siliconFlow.supportedKinds.isEmpty)
        #expect(Provider.deepSeek.supportedKinds == [.balance])
    }

    @Test
    func addableProvidersExcludeSiliconFlowAndKeepDisplayOrder() {
        #expect(Provider.addableCases == [.deepSeek, .moonshot, .openRouter])
        #expect(Provider.addableCases.map(\.displayName) == [
            "DeepSeek",
            "Moonshot (Kimi)",
            "OpenRouter",
        ])
        #expect(!Provider.addableCases.contains(.siliconFlow))
    }

    @Test
    func siliconFlowStillDecodesFromPersistedJSON() throws {
        let decoded = try JSONDecoder().decode(
            Provider.self,
            from: Data(#""siliconFlow""#.utf8)
        )

        #expect(decoded == .siliconFlow)
        #expect(Provider.allCases.contains(.siliconFlow))
    }
}
