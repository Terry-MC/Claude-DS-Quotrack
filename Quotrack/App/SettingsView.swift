import SwiftUI

/// The full Settings surface: the Account list, the app-wide Polling
/// Interval, the Launch at Login toggle, and why unsupported Providers are
/// absent. Account editing includes the per-Account low-Balance threshold,
/// which defaults to off.
@MainActor
struct SettingsView: View {
    let manager: AccountManager
    let settings: SettingsModel
    /// Resolved when the add sheet opens so the tester follows the current
    /// data-source mode.
    let makeConnectionTester: @MainActor () -> any ConnectionTesting
    var onAccountsChanged: () -> Void = {}

    @State private var sheet: AccountSheet?
    @State private var accountPendingDeletion: Account?
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                accountsSection
                Divider()
                pollingSection
                Divider()
                launchAtLoginSection
                Divider()
                unsupportedProvidersSection
            }
            .padding(20)
        }
        .frame(minWidth: 520, minHeight: 520)
        .onAppear {
            settings.refreshLoginItemStatus()
        }
        .onChange(of: manager.accounts) {
            onAccountsChanged()
        }
        .sheet(item: $sheet) { sheet in
            AccountFormView(
                mode: sheet.mode,
                manager: manager,
                connectionTester: makeConnectionTester()
            )
        }
        .confirmationDialog(
            "删除账户？",
            isPresented: Binding(
                get: { accountPendingDeletion != nil },
                set: { if !$0 { accountPendingDeletion = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("删除", role: .destructive) {
                deletePendingAccount()
            }
            Button("取消", role: .cancel) {
                accountPendingDeletion = nil
            }
        } message: {
            Text("该账户的钥匙串凭证和已保存的余额快照都会被移除。")
        }
    }

    private var accountsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(UIStrings.settingsAccountsTitle)

            if manager.accounts.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(UIStrings.emptyAccountsTitle)
                        .font(.headline)
                    Text(UIStrings.emptyAccountsDescription)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
            } else {
                VStack(spacing: 0) {
                    ForEach(manager.accounts) { account in
                        AccountRow(
                            account: account,
                            onEdit: { sheet = .edit(account) },
                            onDelete: {
                                errorMessage = nil
                                accountPendingDeletion = account
                            }
                        )
                        if account.id != manager.accounts.last?.id {
                            Divider()
                        }
                    }
                }
                .padding(.horizontal, 12)
                .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))
            }

            HStack(spacing: 12) {
                Button(UIStrings.addAccount) {
                    errorMessage = nil
                    sheet = .add
                }
                Spacer(minLength: 0)
                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .lineLimit(2)
                }
            }
        }
    }

    private var pollingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle(UIStrings.settingsPollingTitle)
            Stepper(
                value: Binding(
                    get: { settings.pollingIntervalMinutes },
                    set: { settings.setPollingInterval(minutes: $0) }
                ),
                in: AppSettings.pollingIntervalRange
            ) {
                Text("\(UIStrings.pollingIntervalLabel)：\(settings.pollingIntervalMinutes) \(UIStrings.minutesUnit)")
            }
            Text(UIStrings.pollingIntervalHint)
                .font(.caption)
                .foregroundStyle(.secondary)
            if let settingsErrorMessage = settings.settingsErrorMessage {
                Text(settingsErrorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private var launchAtLoginSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle(UIStrings.settingsLaunchAtLoginTitle)
            Toggle(
                UIStrings.launchAtLoginLabel,
                isOn: Binding(
                    get: { settings.isLaunchAtLoginEnabled },
                    set: { settings.setLaunchAtLogin($0) }
                )
            )
            Text(UIStrings.launchAtLoginHint)
                .font(.caption)
                .foregroundStyle(.secondary)
            if settings.requiresApproval {
                HStack(spacing: 8) {
                    Text(UIStrings.launchAtLoginRequiresApproval)
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                    Button(UIStrings.openLoginItemsSettings) {
                        settings.openLoginItemsSettings()
                    }
                    .controlSize(.small)
                }
            }
            if let loginItemErrorMessage = settings.loginItemErrorMessage {
                Text(loginItemErrorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private var unsupportedProvidersSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle(UIStrings.settingsUnsupportedTitle)
            Text(UIStrings.unsupportedProvidersExplanation)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.headline)
    }

    private func deletePendingAccount() {
        guard let account = accountPendingDeletion else {
            return
        }
        do {
            try manager.deleteAccount(id: account.id)
        } catch {
            errorMessage = error.localizedDescription
        }
        accountPendingDeletion = nil
    }
}

private enum AccountSheet: Identifiable {
    case add
    case edit(Account)

    var id: String {
        switch self {
        case .add: "add"
        case let .edit(account): "edit-\(account.id.uuidString)"
        }
    }

    var mode: AccountFormView.Mode {
        switch self {
        case .add: .add
        case let .edit(account): .edit(account)
        }
    }
}

@MainActor
private struct AccountRow: View {
    let account: Account
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(account.label)
                    .font(.headline)
                Text(detailText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            Button("编辑", action: onEdit)
            Button("删除", role: .destructive, action: onDelete)
        }
        .padding(.vertical, 8)
    }

    private var detailText: String {
        var parts = [account.provider.displayName]
        if let region = account.region {
            parts.append(region.displayName)
        }
        if let threshold = account.lowBalanceThreshold {
            parts.append("\(UIStrings.lowBalanceThresholdSaved) \(threshold.description)")
        }
        return parts.joined(separator: " · ")
    }
}
