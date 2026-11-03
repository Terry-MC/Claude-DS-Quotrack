import Foundation
import Testing

struct ThresholdInputTests {
    @Test(arguments: [
        ("", nil),
        ("10", Decimal(string: "10")),
        ("10.5", Decimal(string: "10.5")),
        ("1,000", Decimal(string: "1000")),
        ("1,000.50", Decimal(string: "1000.50")),
        ("10,5", Decimal(string: "10.5")),
    ])
    func validThresholdTextParsesCompletely(
        _ text: String,
        _ expected: Decimal?
    ) {
        switch ThresholdInput.parseOptionalDecimal(text) {
        case let .success(value):
            #expect(value == expected)
        case .failure:
            Issue.record("Expected \(text) to parse")
        }
    }

    @Test(arguments: ["12abc", "12元", "1.2.3", "abc"])
    func invalidThresholdTextIsRejected(_ text: String) {
        switch ThresholdInput.parseOptionalDecimal(text) {
        case .success:
            Issue.record("Expected \(text) to be rejected")
        case .failure:
            break
        }
    }

    @Test
    func thresholdPairsUseTheAccountKindRange() {
        switch ThresholdInput.parseThresholds(
            warningText: "10",
            criticalText: "5",
            kind: .subscription
        ) {
        case let .success(thresholds):
            #expect(thresholds.warning == 10)
            #expect(thresholds.critical == 5)
        case .failure:
            Issue.record("Expected valid subscription thresholds")
        }

        switch ThresholdInput.parseThresholds(
            warningText: "0",
            criticalText: "",
            kind: .balance
        ) {
        case .success:
            Issue.record("Expected balance zero to be rejected")
        case let .failure(error):
            #expect(error == .invalidThreshold)
        }

        switch ThresholdInput.parseThresholds(
            warningText: "101",
            criticalText: "",
            kind: .subscription
        ) {
        case .success:
            Issue.record("Expected subscription 101 to be rejected")
        case let .failure(error):
            #expect(error == .invalidThreshold)
        }
    }
}
