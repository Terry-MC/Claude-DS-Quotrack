import Foundation

/// The single live adapter map. The monitor's registry and the onboarding
/// connection tester both build from this list, so a Provider cannot be wired
/// into one seam and silently forgotten in the other.
///
/// SiliconFlow is intentionally absent: v1 Accounts remain decodable, but v2
/// never uses their credential or queries their endpoint.
enum LiveBalanceAdapters {
    static func make(
        credentialStore: any CredentialStore,
        transport: any HTTPTransport = URLSessionTransport(),
        now: @escaping @Sendable () -> Date = { Date() }
    ) -> [Provider: any CredentialBalanceAdapter] {
        [
            .deepSeek: DeepSeekAdapter(
                transport: transport,
                credentialStore: credentialStore,
                now: now
            ),
            .moonshot: MoonshotAdapter(
                transport: transport,
                credentialStore: credentialStore,
                now: now
            ),
            .openRouter: OpenRouterAdapter(
                transport: transport,
                credentialStore: credentialStore,
                now: now
            ),
        ]
    }
}
