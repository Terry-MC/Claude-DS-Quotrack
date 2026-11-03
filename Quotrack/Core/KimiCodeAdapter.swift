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
            let quota = try decoded.resolvedQuota()
            return QuotaSnapshot(
                accountID: accountID,
                limit: quota.limit,
                remaining: quota.remaining,
                resetAt: quota.resetAt,
                fetchedAt: now(),
                windows: quota.windows.isEmpty ? nil : quota.windows
            )
        } catch let error as BalanceProviderError {
            throw error
        } catch {
            throw BalanceProviderError.malformedResponse
        }
    }

    fileprivate static func isFiveHour(_ window: WindowEntry?) -> Bool {
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
           envelope.data.hasQuotaData {
            return envelope.data
        }
        if let root = try? decoder.decode(UsageResponse.self, from: body),
           root.hasQuotaData {
            return root
        }
        throw BalanceProviderError.malformedResponse
    }
}

private struct UsageEnvelope: Decodable {
    let data: UsageResponse
}

private struct ResolvedQuota {
    let limit: Decimal
    let remaining: Decimal
    let resetAt: Date?
    let windows: [QuotaWindow]
}

/// The name-keyed ratio pools introduced with the newer Kimi Code quota model.
private enum RatioKey: String, CaseIterable {
    case fiveHour = "limit_5h"
    case week = "limit_7d"
    case monthTotal = "limit_month_total"
    case monthCode = "limit_month_code"

    var title: String {
        switch self {
        case .fiveHour: "5 小时窗口"
        case .week: "本周用量"
        case .monthTotal: "本月用量"
        case .monthCode: "本月 Code 用量"
        }
    }
}

private struct RatioPool: Decodable, Equatable {
    let usedRatio: FlexibleDecimal?
    let resetTime: FlexibleDate?

    private enum CodingKeys: String, CodingKey {
        case usedRatio = "used_ratio"
        case resetTime = "reset_time"
    }

    /// `used_ratio` is normally 0...1. Some clients have observed values
    /// already expressed as percentages, so values above 1 are treated as a
    /// percentage rather than doubled.
    var remainingPercent: Decimal? {
        guard let raw = usedRatio?.value, raw >= 0 else {
            return nil
        }
        let usedPercent = raw > 1 ? raw : raw * 100
        return max(0, min(100, 100 - usedPercent))
    }
}

private struct UsagePools: Decodable, Equatable {
    let fiveHour: RatioPool?
    let week: RatioPool?
    let monthTotal: RatioPool?
    let monthCode: RatioPool?

    private enum CodingKeys: String, CodingKey {
        case fiveHour = "limit_5h"
        case week = "limit_7d"
        case monthTotal = "limit_month_total"
        case monthCode = "limit_month_code"
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        fiveHour = try? container.decodeIfPresent(RatioPool.self, forKey: .fiveHour)
        week = try? container.decodeIfPresent(RatioPool.self, forKey: .week)
        monthTotal = try? container.decodeIfPresent(RatioPool.self, forKey: .monthTotal)
        monthCode = try? container.decodeIfPresent(RatioPool.self, forKey: .monthCode)
    }

    var hasAny: Bool {
        fiveHour != nil || week != nil || monthTotal != nil || monthCode != nil
    }

    func pool(for key: RatioKey) -> RatioPool? {
        switch key {
        case .fiveHour: fiveHour
        case .week: week
        case .monthTotal: monthTotal
        case .monthCode: monthCode
        }
    }

    var ordered: [(key: RatioKey, pool: RatioPool)] {
        RatioKey.allCases.compactMap { key in
            guard let pool = pool(for: key) else {
                return nil
            }
            return (key, pool)
        }
    }

    /// Weekly first, then the monthly aggregate pools. The 5-hour burst
    /// window is a secondary detail and only becomes primary when no
    /// weekly/monthly pool is usable.
    var primary: (key: RatioKey, pool: RatioPool)? {
        for key in [RatioKey.week, .monthTotal, .monthCode] {
            if let pool = pool(for: key), pool.remainingPercent != nil {
                return (key, pool)
            }
        }
        return nil
    }
}

private struct UsageResponse: Decodable {
    let usage: UsageEntry?
    let limits: [LimitEntry]
    let usages: UsagePools?
    let hasUsageKey: Bool

    private enum CodingKeys: String, CodingKey {
        case usage
        case limits
        case usages
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
        usages = (try? container.decodeIfPresent(
            UsagePools.self,
            forKey: .usages
        )) ?? nil
    }

    var hasQuotaData: Bool {
        hasUsageKey || !limits.isEmpty || (usages?.hasAny ?? false)
    }

    /// The new `usages` ratio model and the legacy `usage` + `limits` model
    /// coexist in real responses. Prefer a present legacy weekly usage, then
    /// weekly/monthly ratio pools, then the 5-hour window as a last resort.
    func resolvedQuota() throws -> ResolvedQuota {
        if hasUsageKey {
            guard let usage,
                  usage.isValid,
                  let limit = usage.limit?.value,
                  limit > 0,
                  let remaining = usage.remaining?.value else {
                throw BalanceProviderError.malformedResponse
            }
            var windows = legacyWindows()
            // `usage` is the weekly metric, so the ratio week would duplicate it.
            windows += ratioWindows(excluding: .week)
            return ResolvedQuota(
                limit: limit,
                remaining: remaining,
                resetAt: usage.resetTime?.value,
                windows: deduped(windows)
            )
        }

        if let primary = usages?.primary,
           let remaining = primary.pool.remainingPercent {
            var windows = ratioWindows(excluding: primary.key)
            if !windows.contains(where: { $0.name == "5 小时窗口" }) {
                windows += legacyWindows()
            }
            return ResolvedQuota(
                limit: 100,
                remaining: remaining,
                resetAt: primary.pool.resetTime?.value,
                windows: deduped(windows)
            )
        }

        if let firstIndex = limits.firstIndex(where: {
            $0.detail?.isValid == true
        }),
            let primary = limits[firstIndex].detail,
            let limit = primary.limit?.value,
            limit > 0,
            let remaining = primary.remaining?.value {
            var windows = legacyWindows(excluding: firstIndex)
            windows += ratioWindows()
            return ResolvedQuota(
                limit: limit,
                remaining: remaining,
                resetAt: primary.resetTime?.value,
                windows: deduped(windows)
            )
        }

        throw BalanceProviderError.malformedResponse
    }

    private func legacyWindows(
        excluding excludedIndex: Int? = nil
    ) -> [QuotaWindow] {
        limits.enumerated().compactMap { index, limit in
            guard index != excludedIndex,
                  let detail = limit.detail,
                  let windowLimit = detail.limit?.value,
                  windowLimit > 0,
                  let windowRemaining = detail.remaining?.value else {
                return nil
            }
            let name = KimiCodeAdapter.isFiveHour(limit.window)
                ? "5 小时窗口"
                : "额度窗口 \(index + 1)"
            return QuotaWindow(
                name: name,
                limit: windowLimit,
                remaining: windowRemaining,
                resetAt: detail.resetTime?.value
            )
        }
    }

    private func ratioWindows(excluding excluded: RatioKey? = nil) -> [QuotaWindow] {
        usages?.ordered.compactMap { key, pool in
            guard key != excluded,
                  let remaining = pool.remainingPercent else {
                return nil
            }
            return QuotaWindow(
                name: key.title,
                limit: 100,
                remaining: remaining,
                resetAt: pool.resetTime?.value
            )
        } ?? []
    }

    private func deduped(_ windows: [QuotaWindow]) -> [QuotaWindow] {
        var seen: Set<String> = []
        return windows.filter { seen.insert($0.name).inserted }
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
