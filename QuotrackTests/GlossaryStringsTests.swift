import Testing

/// Guards the user-facing strings that encode glossary terms. The wire JSON
/// keys stay Provider-defined, but domain labels must match GLOSSARY.md.
struct GlossaryStringsTests {
    @Test
    func unsupportedProvidersUseTheGlossaryTerm() {
        #expect(UIStrings.settingsUnsupportedTitle == "不可查厂商")
    }

    @Test
    func settingsExplainsUnsupportedAndDeferredIntegrations() {
        let unsupported = UIStrings.unsupportedProvidersExplanation
        let deferred = UIStrings.settingsDeferredIntegrationsExplanation

        #expect(unsupported.contains("SiliconFlow"))
        #expect(unsupported.contains(UIStrings.unsupportedProviderState))
        #expect(unsupported.contains("OpenAI"))
        #expect(unsupported.contains("Anthropic"))
        #expect(unsupported.contains("Gemini"))

        #expect(deferred.contains("WorkBuddy"))
        #expect(deferred.contains("Claude Pro/Max"))
        #expect(deferred.contains("ChatGPT/Codex"))
        #expect(deferred.contains("Gemini CLI"))
        #expect(deferred.contains("SuperGrok"))
        #expect(deferred.contains("OAuth"))
        #expect(deferred.contains("CLI"))
    }
}
