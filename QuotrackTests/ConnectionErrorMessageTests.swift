import Testing

struct ConnectionErrorMessageTests {
    @Test
    func kimiCodeAuthenticationFailuresPointAtTheKeyAndRegion() {
        #expect(
            ConnectionErrorMessage.text(
                for: BalanceProviderError.authentication,
                provider: .moonshot,
                kind: .subscription
            ) == UIStrings.kimiCodeAuthenticationError
        )
    }

    @Test
    func moonshotBalanceKeepsTheGenericRegionMessage() {
        #expect(
            ConnectionErrorMessage.text(
                for: BalanceProviderError.authentication,
                provider: .moonshot,
                kind: .balance
            ) == UIStrings.regionAuthenticationError
        )
    }

    @Test
    func otherProvidersKeepTheirOwnMessage() {
        #expect(
            ConnectionErrorMessage.text(
                for: BalanceProviderError.authentication,
                provider: .deepSeek
            ) == UIStrings.authenticationError
        )
    }
}
