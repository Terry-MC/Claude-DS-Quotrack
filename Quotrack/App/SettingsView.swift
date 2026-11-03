import SwiftUI

/// The full Settings surface: the Account list, the app-wide Polling
/// Interval, the Launch at Login toggle, and why unsupported and deferred
/// Providers are absent. Account editing includes the per-Account thresholds.
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
            VStack(alignment: .leading, spacing: 16) {
                pageHeader
                accountsSection
                pollingSection
                launchAtLoginSection
                supportSection
            }
            .padding(22)
        }
        .frame(minWidth: 560, minHeight: 640)
        .scrollIndicators(.never)
        .quotrackWindowBackground()
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
            Text(UIStrings.deleteAccountConfirmation)
        }
    }

    private var pageHeader: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("设置")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(UITheme.textPrimary)
            Text("管理账户、阈值与轮询")
                .font(.system(size: 10.5))
                .tracking(0.3)
                .foregroundStyle(UITheme.textTertiary)
        }
        .padding(.horizontal, 2)
    }

    private var accountsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionTitle(UIStrings.settingsAccountsTitle)
                Spacer()
                Button(UIStrings.addAccount) {
                    errorMessage = nil
                    sheet = .add
                }
                .buttonStyle(AccentButtonStyle())
            }

            if manager.accounts.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        Image(systemName: "person.crop.circle.badge.plus")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(UITheme.textSecondary)
                            .frame(width: 34, height: 34)
                            .background(
                                UITheme.control,
                                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                            )
                        VStack(alignment: .leading, spacing: 2) {
                            Text(UIStrings.emptyAccountsTitle)
                                .font(.system(size: 12.5, weight: .semibold))
                                .foregroundStyle(UITheme.textPrimary)
                            Text(UIStrings.emptyAccountsDescription)
                                .font(.system(size: 10.5))
                                .foregroundStyle(UITheme.textSecondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(
                    Color.black.opacity(0.16),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(manager.accounts.enumerated()), id: \.element.id) { index, account in
                        AccountRow(
                            account: account,
                            onEdit: { sheet = .edit(account) },
                            onDelete: {
                                errorMessage = nil
                                accountPendingDeletion = account
                            }
                        )
                        if index < manager.accounts.count - 1 {
                            Rectangle()
                                .fill(UITheme.hairlineSubtle)
                                .frame(height: 1)
                                .padding(.leading, 44)
                        }
                    }
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 10.5))
                    .foregroundStyle(UITheme.red)
                    .lineLimit(2)
            }
        }
        .glassCard(padding: 16)
    }

    private var pollingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(UIStrings.settingsPollingTitle)
            HStack(spacing: 12) {
                Text(UIStrings.pollingIntervalLabel)
                    .font(.system(size: 12))
                    .foregroundStyle(UITheme.textSecondary)
                Spacer()
                Stepper(
                    value: Binding(
                        get: { settings.pollingIntervalMinutes },
                        set: { settings.setPollingInterval(minutes: $0) }
                    ),
                    in: AppSettings.pollingIntervalRange
                ) {
                    Text("\(settings.pollingIntervalMinutes) \(UIStrings.minutesUnit)")
                        .font(.system(size: 12, weight: .medium).monospacedDigit())
                        .foregroundStyle(UITheme.textPrimary)
                }
                .fixedSize()
            }
            Text(UIStrings.pollingIntervalHint)
                .font(.system(size: 10))
                .foregroundStyle(UITheme.textTertiary)
            if let settingsErrorMessage = settings.settingsErrorMessage {
                Text(settingsErrorMessage)
                    .font(.system(size: 10.5))
                    .foregroundStyle(UITheme.red)
            }
        }
        .glassCard(padding: 16)
    }

    private var launchAtLoginSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(UIStrings.settingsLaunchAtLoginTitle)
            Toggle(
                UIStrings.launchAtLoginLabel,
                isOn: Binding(
                    get: { settings.isLaunchAtLoginEnabled },
                    set: { settings.setLaunchAtLogin($0) }
                )
            )
            .toggleStyle(.switch)
            .font(.system(size: 12))
            .foregroundStyle(UITheme.textPrimary)
            .tint(UITheme.accentStart)

            Text(UIStrings.launchAtLoginHint)
                .font(.system(size: 10))
                .foregroundStyle(UITheme.textTertiary)

            if settings.requiresApproval {
                HStack(spacing: 8) {
                    Text(UIStrings.launchAtLoginRequiresApproval)
                        .font(.system(size: 10))
                        .foregroundStyle(UITheme.yellow)
                        .fixedSize(horizontal: false, vertical: true)
                    Button(UIStrings.openLoginItemsSettings) {
                        settings.openLoginItemsSettings()
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
            }
            if let loginItemErrorMessage = settings.loginItemErrorMessage {
                Text(loginItemErrorMessage)
                    .font(.system(size: 10.5))
                    .foregroundStyle(UITheme.red)
            }
        }
        .glassCard(padding: 16)
    }

    private var supportSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(UIStrings.settingsUnsupportedTitle)
            Text(UIStrings.unsupportedProvidersExplanation)
                .font(.system(size: 10.5))
                .foregroundStyle(UITheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Rectangle()
                .fill(UITheme.hairlineSubtle)
                .frame(height: 1)
            Text(UIStrings.settingsDeferredIntegrationsExplanation)
                .font(.system(size: 10.5))
                .foregroundStyle(UITheme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .glassCard(padding: 16)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .tracking(0.4)
            .foregroundStyle(UITheme.textSecondary)
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
        HStack(spacing: 10) {
            ProviderMark(provider: account.provider, size: 28)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(account.label)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(UITheme.textPrimary)
                    TypeTag(
                        text: account.kind.typeTagText,
                        style: account.kind.typeTagStyle
                    )
                    if !account.provider.isSupported {
                        TypeTag(text: UIStrings.unsupportedProviderState, style: .experimental)
                    }
                }
                Text(detailText)
                    .font(.system(size: 10))
                    .foregroundStyle(UITheme.textTertiary)
                    .lineLimit(2)
            }

            Spacer(minLength: 12)

            if account.provider.isSupported {
                GlassIconButton(systemName: "pencil", help: "编辑", size: 24, action: onEdit)
            }
            GlassIconButton(
                systemName: "trash",
                help: "删除",
                tint: UITheme.red.opacity(0.8),
                size: 24,
                action: onDelete
            )
        }
        .padding(.vertical, 9)
    }

    private var detailText: String {
        var parts = [account.provider.displayName]
        if let region = account.region {
            parts.append(region.displayName)
        }

        let thresholds = account.thresholds
        var thresholdParts: [String] = []
        if let warning = thresholds.warning {
            thresholdParts.append(
                "\(UIStrings.warningThresholdShort) \(thresholdValue(warning))"
            )
        }
        if let critical = thresholds.critical {
            thresholdParts.append(
                "\(UIStrings.criticalThresholdShort) \(thresholdValue(critical))"
            )
        }
        parts.append(
            thresholdParts.isEmpty
                ? UIStrings.thresholdUnset
                : thresholdParts.joined(separator: " / ")
        )
        return parts.joined(separator: " · ")
    }

    private func thresholdValue(_ value: Decimal) -> String {
        if account.kind == .subscription {
            return "\(value)%"
        }
        let currency = account.currency
            ?? account.provider.defaultCurrency(for: account.region)
        let symbol = currency?.symbol ?? ""
        return "\(symbol)\(value)"
    }
}
