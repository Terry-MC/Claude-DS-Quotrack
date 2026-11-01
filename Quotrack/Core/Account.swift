import Foundation

/// A single labeled credential for a Provider. A Provider may have several
/// Accounts; each Account is polled and displayed independently.
struct Account: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let provider: Provider
    let label: String
}
