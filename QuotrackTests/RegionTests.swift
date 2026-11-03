import Testing

struct RegionTests {
    @Test
    func onlyMoonshotAndSiliconFlowHaveRegions() {
        #expect(Provider.allCases.filter(\.supportsRegion) == [.moonshot, .siliconFlow])
    }
}
