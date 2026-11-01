import Testing

/// Guards the user-facing strings that encode glossary terms. The wire JSON
/// keys stay Provider-defined, but domain labels must match GLOSSARY.md.
struct GlossaryStringsTests {
    @Test
    func unsupportedProvidersUseTheGlossaryTerm() {
        #expect(UIStrings.settingsUnsupportedTitle == "不可查厂商")
    }
}
