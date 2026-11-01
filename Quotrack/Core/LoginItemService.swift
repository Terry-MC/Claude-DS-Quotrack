import Foundation
import ServiceManagement

/// The system's login-item registration state, reduced to the cases the
/// Settings UI distinguishes.
enum LoginItemStatus: Equatable, Sendable {
    case notRegistered
    case enabled
    case requiresApproval
    case notFound
}

/// The seam between Settings and ServiceManagement. Production uses
/// `SMAppService`; tests inject a fake and never touch the system service.
@MainActor
protocol LoginItemService: AnyObject {
    var status: LoginItemStatus { get }
    func register() throws
    func unregister() throws
    func openSystemSettingsLoginItems()
}

enum LoginItemServiceError: Error, Equatable, LocalizedError {
    case registrationFailed(String)
    case unregistrationFailed(String)

    var errorDescription: String? {
        switch self {
        case let .registrationFailed(detail):
            "无法启用开机启动：\(detail)"
        case let .unregistrationFailed(detail):
            "无法关闭开机启动：\(detail)"
        }
    }
}

/// Registers the app itself as a login item through `SMAppService.mainApp`.
/// The system status is the source of truth; this type does not persist a
/// separate preference. Registering may leave the item needing approval, in
/// which case `SettingsModel` re-reads the status and opens the System
/// Settings pane.
@MainActor
final class SMAppServiceLoginItemService: LoginItemService {
    var status: LoginItemStatus {
        Self.map(SMAppService.mainApp.status)
    }

    func register() throws {
        do {
            try SMAppService.mainApp.register()
        } catch {
            guard Self.isIdempotentRegisterError(error) else {
                throw LoginItemServiceError.registrationFailed(error.localizedDescription)
            }
        }
    }

    func unregister() throws {
        do {
            try SMAppService.mainApp.unregister()
        } catch {
            guard Self.isIdempotentUnregisterError(error) else {
                throw LoginItemServiceError.unregistrationFailed(error.localizedDescription)
            }
        }
    }

    func openSystemSettingsLoginItems() {
        SMAppService.openSystemSettingsLoginItems()
    }

    /// Registering an item that is already registered reports
    /// `kSMErrorAlreadyRegistered`; the desired end state is already reached.
    nonisolated static func isIdempotentRegisterError(_ error: any Error) -> Bool {
        serviceError(error, hasCode: kSMErrorAlreadyRegistered)
    }

    /// Unregistering an item that is already gone reports
    /// `kSMErrorJobNotFound`; the desired end state is already reached.
    nonisolated static func isIdempotentUnregisterError(_ error: any Error) -> Bool {
        serviceError(error, hasCode: kSMErrorJobNotFound)
    }

    nonisolated private static func serviceError(
        _ error: any Error,
        hasCode code: Int
    ) -> Bool {
        let nsError = error as NSError
        return nsError.domain == SMAppServiceErrorDomain && nsError.code == code
    }

    nonisolated private static func map(_ status: SMAppService.Status) -> LoginItemStatus {
        switch status {
        case .notRegistered: .notRegistered
        case .enabled: .enabled
        case .requiresApproval: .requiresApproval
        case .notFound: .notFound
        @unknown default: .notFound
        }
    }
}
