import Foundation

enum ThresholdInputError: Error, Equatable, Sendable {
    case invalidNumber
    case invalidThreshold
}

/// Parses the two threshold text fields. It accepts a plain decimal with ".",
/// one decimal comma, or thousands grouping, and rejects numeric prefixes such
/// as "12abc" or "12元". Both the Settings form and onboarding use this type so
/// they cannot drift.
enum ThresholdInput {
    static func parseOptionalDecimal(
        _ text: String
    ) -> Result<Decimal?, ThresholdInputError> {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .success(nil)
        }
        guard let normalized = normalizedNumber(trimmed),
              let value = Decimal(
                string: normalized,
                locale: Locale(identifier: "en_US_POSIX")
              ) else {
            return .failure(.invalidNumber)
        }
        return .success(value)
    }

    static func parseThresholds(
        warningText: String,
        criticalText: String,
        kind: AccountKind
    ) -> Result<AccountThresholds, ThresholdInputError> {
        let warning: Decimal?
        switch parseOptionalDecimal(warningText) {
        case let .success(value):
            warning = value
        case .failure:
            return .failure(.invalidNumber)
        }

        let critical: Decimal?
        switch parseOptionalDecimal(criticalText) {
        case let .success(value):
            critical = value
        case .failure:
            return .failure(.invalidNumber)
        }

        let thresholds = AccountThresholds(warning: warning, critical: critical)
        do {
            try thresholds.validate(for: kind)
            return .success(thresholds)
        } catch {
            return .failure(.invalidThreshold)
        }
    }

    private static func normalizedNumber(_ text: String) -> String? {
        let dotCount = text.filter { $0 == "." }.count
        let commaCount = text.filter { $0 == "," }.count

        if commaCount > 0 {
            if dotCount > 0 {
                guard dotCount == 1,
                      let dotIndex = text.firstIndex(of: ".") else {
                    return nil
                }
                let integerPart = String(text[..<dotIndex])
                let fractionPart = String(text[text.index(after: dotIndex)...])
                guard isThousandsGrouped(integerPart),
                      !fractionPart.isEmpty,
                      fractionPart.allSatisfy(isASCIIDigit) else {
                    return nil
                }
                return text.replacingOccurrences(of: ",", with: "")
            }

            if isThousandsGrouped(text) {
                return text.replacingOccurrences(of: ",", with: "")
            }

            guard commaCount == 1,
                  let commaIndex = text.firstIndex(of: ",") else {
                return nil
            }
            let integerPart = String(text[..<commaIndex])
            let fractionPart = String(text[text.index(after: commaIndex)...])
            guard !integerPart.isEmpty,
                  !fractionPart.isEmpty,
                  fractionPart.count <= 2,
                  integerPart.allSatisfy(isASCIIDigit),
                  fractionPart.allSatisfy(isASCIIDigit) else {
                return nil
            }
            return integerPart + "." + fractionPart
        }

        guard dotCount <= 1 else {
            return nil
        }
        let digits = text.filter(isASCIIDigit)
        guard !digits.isEmpty,
              text.allSatisfy({ isASCIIDigit($0) || $0 == "." }) else {
            return nil
        }
        return text
    }

    private static func isThousandsGrouped(_ text: String) -> Bool {
        let parts = text.split(separator: ",", omittingEmptySubsequences: false)
        guard parts.count >= 2,
              let first = parts.first,
              (1...3).contains(first.count),
              first.allSatisfy(isASCIIDigit) else {
            return false
        }
        return parts.dropFirst().allSatisfy {
            $0.count == 3 && $0.allSatisfy(isASCIIDigit)
        }
    }

    private static func isASCIIDigit(_ character: Character) -> Bool {
        character >= "0" && character <= "9"
    }
}
