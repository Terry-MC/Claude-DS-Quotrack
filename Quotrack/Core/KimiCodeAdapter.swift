import Foundation

/// The Kimi Code subscription adapter. It calls the undocumented usage
/// endpoint with an `sk-kimi-…` key and reports the weekly quota as the primary
/// Quota, with the 5-hour window as secondary detail.
///
/// The endpoint is not part of the public Moonshot API contract. Decode
/// defensively and treat any missing primary quota as a malformed response
/// rather than fabricating a zero.
struct KimiCodeAdapter: AccountProvider, CredentialAccountAdapter {
    static let domesticEndpoint = URL(
        string: "https://api.kimi.com/coding/v1/usages"
    )!
    static let internationalEndpoint = URL(
        string: "https://api.kimi.ai/coding/v1/usages"
    )!

    private let http: AuthenticatedHTTPClient
    private let now: @Sendable () -> Date

    init(
        transport: any HTTPTransport,
        credentialStore: any CredentialStore,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.http = AuthenticatedHTTPClient(
            transport: transport,
            credentialStore: credentialStore,
            now: now
        )
        self.now = now
    }

    func fetchSnapshot(for account: Account) async throws -> AccountSnapshot {
        guard account.kind == .subscription else {
            throw BalanceProviderError.unsupportedAccountKind
        }
        let response = try await http.get(
            Self.endpoint(for: account.region),
            accountID: account.id
        )
        return .quota(try snapshot(from: response, accountID: account.id))
    }

    func fetchSnapshot(
        region: Region?,
        credential: String,
        kind: AccountKind
    ) async throws -> AccountSnapshot {
        guard kind == .subscription else {
            throw BalanceProviderError.unsupportedAccountKind
        }
        let response = try await http.get(
            Self.endpoint(for: region),
            credential: credential
        )
        return .quota(try snapshot(from: response, accountID: UUID()))
    }

    static func endpoint(for region: Region?) -> URL {
        region == .international ? internationalEndpoint : domesticEndpoint
    }

    private func snapshot(
        from response: HTTPResponse,
        accountID: Account.ID
    ) throws -> QuotaSnapshot {
        do {
            let decoded = try Self.decodeUsage(from: response.body)
            guard let normalized = decoded.normalized else {
                throw BalanceProviderError.malformedResponse
            }

            let primary = normalized.primary
            guard let limit = primary.limit?.value,
                  limit > 0,
                  let remaining = primary.remaining?.value else {
                throw BalanceProviderError.malformedResponse
            }

            let windows = normalized.secondaries.enumerated().compactMap {
                index,
                secondary -> QuotaWindow? in
                guard let detail = secondary.detail,
                      let windowLimit = detail.limit?.value,
                      windowLimit > 0,
                      let windowRemaining = detail.remaining?.value else {
                    return nil
                }
                let name = Self.isFiveHour(secondary.window)
                    ? "5 小时窗口"
                    : "额度窗口 \(index + 1)"
                return QuotaWindow(
                    name: name,
                    limit: windowLimit,
                    remaining: windowRemaining,
                    resetAt: detail.resetTime?.value
                )
            }

            return QuotaSnapshot(
                accountID: accountID,
                limit: limit,
                remaining: remaining,
                resetAt: primary.resetTime?.value,
                fetchedAt: now(),
                windows: windows.isEmpty ? nil : windows
            )
        } catch let error as BalanceProviderError {
            throw error
        } catch {
            throw BalanceProviderError.malformedResponse
        }
    }

    private static func isFiveHour(_ window: WindowEntry?) -> Bool {
        guard let duration = window?.duration?.value else {
            return false
        }
        switch window?.timeUnit {
        case "TIME_UNIT_SECOND":
            return duration == 18_000
        case "TIME_UNIT_MINUTE", .none:
            return duration == 300
        default:
            return false
        }
    }

    private static func decodeUsage(from body: Data) throws -> UsageResponse {
        let decoder = JSONDecoder()
        if let envelope = try? decoder.decode(UsageEnvelope.self, from: body),
           envelope.data.normalized != nil {
            return envelope.data
        }
        if let root = try? decoder.decode(UsageResponse.self, from: body) {
            return root
        }
        throw BalanceProviderError.malformedResponse
    }
}

private struct UsageEnvelope: Decodable {
    let data: UsageResponse
}

private struct UsageResponse: Decodable {
    let usage: UsageEntry?
    let limits: [LimitEntry]
    let hasUsageKey: Bool

    private enum CodingKeys: String, CodingKey {
        case usage
        case limits
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        hasUsageKey = container.contains(.usage)
        usage = try container.decodeIfPresent(UsageEntry.self, forKey: .usage)
        if let raw = try? container.decode(
            [Failable<LimitEntry>].self,
            forKey: .limits
        ) {
            limits = raw.compactMap(\.value)
        } else {
            limits = []
        }
    }

    /// A present weekly usage is authoritative: if it is invalid, the whole
    /// response is malformed rather than promoting a 5-hour window to primary.
    /// Limits are secondary windows and are decoded individually, so one bad
    /// entry cannot discard a valid weekly quota.
    var normalized: (primary: UsageEntry, secondaries: [LimitEntry])? {
        if hasUsageKey {
            guard let usage, usage.isValid else {
                return nil
            }
            return (usage, limits.filter { $0.detail?.isValid == true })
        }

        guard let firstIndex = limits.firstIndex(where: {
            $0.detail?.isValid == true
        }), let primary = limits[firstIndex].detail else {
            return nil
        }
        let secondaries = limits.enumerated()
            .filter {
                $0.offset != firstIndex && $0.element.detail?.isValid == true
            }
            .map(\.element)
        return (primary, secondaries)
    }
}

private struct Failable<Value: Decodable>: Decodable {
    let value: Value?

    init(from decoder: any Decoder) throws {
        value = try? Value(from: decoder)
    }
}

private struct UsageEntry: Decodable, Equatable {
    let limit: FlexibleDecimal?
    let remaining: FlexibleDecimal?
    let resetTime: FlexibleDate?

    var isValid: Bool {
        guard let limit = limit?.value,
              limit > 0,
              let remaining = remaining?.value,
              remaining >= 0 else {
            return false
        }
        return true
    }
}

private struct LimitEntry: Decodable, Equatable {
    let window: WindowEntry?
    let detail: UsageEntry?
}

private struct WindowEntry: Decodable, Equatable {
    let duration: FlexibleInt?
    let timeUnit: String?
}

private struct FlexibleInt: Decodable, Equatable {
    let value: Int

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let int = try? container.decode(Int.self) {
            value = int
            return
        }
        if let string = try? container.decode(String.self),
           let int = Int(string) {
            value = int
            return
        }
        if let double = try? container.decode(Double.self) {
            value = Int(double)
            return
        }
        throw DecodingError.typeMismatch(
            FlexibleInt.self,
            DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Expected an integer or numeric string"
            )
        )
    }
}

private struct FlexibleDecimal: Decodable, Equatable {
    let value: Decimal

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            guard let value = Decimal(
                string: string,
                locale: Locale(identifier: "en_US_POSIX")
            ) else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Invalid decimal string"
                )
            }
            self.value = value
            return
        }
        if let int = try? container.decode(Int.self) {
            self.value = Decimal(int)
            return
        }
        if let double = try? container.decode(Double.self) {
            self.value = Decimal(
                string: String(double),
                locale: Locale(identifier: "en_US_POSIX")
            ) ?? Decimal(double)
            return
        }
        throw DecodingError.typeMismatch(
            FlexibleDecimal.self,
            DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Expected a number or numeric string"
            )
        )
    }
}

private struct FlexibleDate: Decodable, Equatable {
    let value: Date

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        guard let date = Self.parse(string) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid ISO 8601 date"
            )
        }
        self.value = date
    }

    private static func parse(_ string: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [
            .withInternetDateTime,
            .withFractionalSeconds,
        ]
        if let date = fractional.date(from: string) {
            return date
        }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: string)
    }
}
