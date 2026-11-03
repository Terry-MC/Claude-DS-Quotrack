import SwiftUI

/// Collects Provider, Region when applicable, Account Kind, label, credential,
/// and the two health thresholds when adding an Account; when editing, it
/// shows identity read-only and collects a new label, an optional credential
/// replacement, and the thresholds. A saved credential is never read back into
/// the field.
@MainActor
struct AccountFormView: View {
    enum Mode {
        case add
        case edit(Account)
    }

    let mode: Mode
    let manager: AccountManager
    let connectionTester: any ConnectionTesting

    @Environment(\.dismiss) private var dismiss
    @State private var provider: Provider
    @State private var region: Region
    @State private var kind: AccountKind
    @State private var label: String
    @State private var credential = ""
    @State private var warningThresholdText: String
    @State private var criticalThresholdText: String
    @State private var errorMessage: String?
    @State private var isSaving = false

    init(
        mode: Mode,
        manager: AccountManager,
        connectionTester: any ConnectionTesting
    ) {
        self.mode = mode
        self.manager = manager
        self.connectionTester = connectionTester
        switch mode {
        case .add:
            _provider = State(initialValue: .deepSeek)
            _region = State(initialValue: .domestic)
            _kind = State(initialValue: .balance)
            _label = State(initialValue: "")
            _warningThresholdText = State(initialValue: "")
            _criticalThresholdText = State(initialValue: "")
        case let .edit(account):
            _provider = State(initialValue: account.provider)
            _region = State(initialValue: account.region ?? .domestic)
            _kind = State(initialValue: account.kind)
            _label = State(initialValue: account.label)
            _warningThresholdText = State(
                initialValue: account.warningThreshold?.description ?? ""
            )
            _criticalThresholdText = State(
                initialValue: account.criticalThreshold?.description ?? ""
            )
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Rectangle()
                .fill(UITheme.hairline)
                .frame(height: 1)
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    identityCard
                    credentialCard
                    thresholdCard
                    if case .edit = mode {
                        Text("已保存的凭证不会显示。留空则保持现有凭证不变。")
                            .font(.system(size: 10))
                            .foregroundStyle(UITheme.textTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(20)
            }
            .scrollIndicators(.never)

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(UITheme.red)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 10)
            }

            Rectangle()
                .fill(UITheme.hairline)
                .frame(height: 1)
            footer
        }
        .frame(width: 480)
        .quotrackWindowBackground()
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(UITheme.textPrimary)
                Text(
                    isEditing
                        ? "修改标签、凭证或健康阈值"
                        : "连接测试通过后才会保存账户"
                )
                .font(.system(size: 10.5))
                .foregroundStyle(UITheme.textTertiary)
            }
            Spacer(minLength: 8)
            ProviderMark(provider: provider, size: 30)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    private var identityCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            formSectionTitle("账户")
            if isEditing {
                LabeledValue(title: "厂商", value: provider.displayName)
            } else {
                LabeledMenu(title: "厂商", selection: providerSelection) {
                    ForEach(Provider.addableCases, id: \.self) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }
            }

            if provider.supportsRegion {
                if isEditing {
                    LabeledValue(title: "区域", value: region.displayName)
                } else {
                    LabeledMenu(title: "区域", selection: regionSelection) {
                        ForEach(Region.allCases, id: \.self) { region in
                            Text(region.displayName).tag(region)
                        }
                    }
                }
            }

            if !isEditing, provider.supportedKinds.count > 1 {
                VStack(alignment: .leading, spacing: 5) {
                    fieldLabel(UIStrings.accountKindLabel)
                    Picker(UIStrings.accountKindLabel, selection: $kind) {
                        ForEach(provider.supportedKinds, id: \.self) { kind in
                            Text(kind.displayName).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .onChange(of: kind) { _, newKind in
                        applyDefaults(for: newKind)
                    }
                }
            } else {
                LabeledValue(
                    title: UIStrings.accountKindLabel,
                    value: kind.displayName
                )
            }
        }
        .glassCard(padding: 14)
    }

    private var credentialCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            formSectionTitle("凭证")
            ThemedTextField(title: "标签", text: $label)
            ThemedTextField(
                title: credentialFieldLabel,
                text: $credential,
                isSecure: true
            )
            if let warning = AccountFormPresentation.credentialWarning(
                for: provider,
                kind: kind
            ) {
                Text(warning)
                    .font(.system(size: 10))
                    .foregroundStyle(UITheme.yellow)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if kind == .subscription,
               !credential.isEmpty,
               !credential.hasPrefix("sk-kimi") {
                Text(UIStrings.kimiCodeCredentialRequired)
                    .font(.system(size: 10))
                    .foregroundStyle(UITheme.yellow)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .glassCard(padding: 14)
    }

    private var thresholdCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            formSectionTitle(UIStrings.healthThresholdsTitle)
            HStack(spacing: 10) {
                ThemedTextField(
                    title: warningFieldLabel,
                    text: $warningThresholdText
                )
                ThemedTextField(
                    title: criticalFieldLabel,
                    text: $criticalThresholdText
                )
            }
            Text(thresholdHint)
                .font(.system(size: 10))
                .foregroundStyle(UITheme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
            if kind == .balance {
                Text(UIStrings.thresholdCurrencyHint)
                    .font(.system(size: 10))
                    .foregroundStyle(UITheme.textTertiary)
            }
        }
        .glassCard(padding: 14)
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button("取消", role: .cancel) {
                dismiss()
            }
            .buttonStyle(SecondaryButtonStyle())
            .keyboardShortcut(.cancelAction)
            Button(saveButtonTitle, action: save)
                .buttonStyle(AccentButtonStyle())
                .keyboardShortcut(.defaultAction)
                .disabled(
                    label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || isSaving
                )
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private var isEditing: Bool {
        if case .edit = mode {
            return true
        }
        return false
    }

    private var providerSelection: Binding<Provider> {
        Binding(
            get: { provider },
            set: { newProvider in
                let oldCurrency = provider.defaultCurrency(for: region)
                provider = newProvider
                if !newProvider.supportedKinds.contains(kind) {
                    kind = newProvider.supportedKinds.first ?? .balance
                    applyDefaults(for: kind)
                } else if kind == .balance,
                          newProvider.defaultCurrency(for: region) != oldCurrency {
                    applyDefaults(for: kind)
                }
            }
        )
    }

    private var regionSelection: Binding<Region> {
        Binding(
            get: { region },
            set: { newRegion in
                let oldCurrency = provider.defaultCurrency(for: region)
                region = newRegion
                if kind == .balance,
                   provider.defaultCurrency(for: newRegion) != oldCurrency {
                    applyDefaults(for: kind)
                }
            }
        )
    }

    private func applyDefaults(for kind: AccountKind) {
        let defaults = AccountThresholds.defaults(for: kind)
        warningThresholdText = defaults.warning?.description ?? ""
        criticalThresholdText = defaults.critical?.description ?? ""
    }

    private var warningFieldLabel: String {
        kind == .subscription
            ? UIStrings.warningThresholdPercentLabel
            : UIStrings.warningThresholdLabel
    }

    private var criticalFieldLabel: String {
        kind == .subscription
            ? UIStrings.criticalThresholdPercentLabel
            : UIStrings.criticalThresholdLabel
    }

    private var thresholdHint: String {
        kind == .subscription
            ? UIStrings.healthThresholdsPercentHint
            : UIStrings.healthThresholdsHint
    }

    private var title: String {
        switch mode {
        case .add: "添加账户"
        case .edit: "编辑账户"
        }
    }

    private var credentialFieldLabel: String {
        switch mode {
        case .add: "凭证"
        case .edit: "替换凭证（留空则保持不变）"
        }
    }

    private var saveButtonTitle: String {
        guard !isSaving else {
            return UIStrings.onboardingTesting
        }
        switch mode {
        case .add: return UIStrings.onboardingTestAndSave
        case .edit: return "保存"
        }
    }

    private func save() {
        guard let thresholds = validatedThresholds() else {
            return
        }
        errorMessage = nil
        switch mode {
        case .add:
            guard !credential.isEmpty else {
                errorMessage = AccountManagerError.missingCredential.localizedDescription
                return
            }
            let draft = AccountDraft(
                provider: provider,
                region: provider.supportsRegion ? region : nil,
                label: label,
                credential: credential,
                kind: kind
            )
            isSaving = true
            Task {
                await testConnectionAndSave(draft, thresholds: thresholds)
            }
        case let .edit(account):
            saveEdit(account, thresholds: thresholds)
        }
    }

    /// The add flow tests the credential before writing anything, matching
    /// onboarding. A rejected credential leaves no Account or Keychain item.
    private func testConnectionAndSave(
        _ draft: AccountDraft,
        thresholds: AccountThresholds
    ) async {
        defer { isSaving = false }
        let creator = AccountCreator(
            manager: manager,
            connectionTester: connectionTester
        )
        do {
            _ = try await creator.create(draft, thresholds: thresholds)
            dismiss()
        } catch {
            errorMessage = ConnectionErrorMessage.text(
                for: error,
                provider: draft.provider,
                kind: draft.kind
            )
        }
    }

    private func saveEdit(_ account: Account, thresholds: AccountThresholds) {
        do {
            try manager.updateLabel(accountID: account.id, label: label)
            if !credential.isEmpty {
                try manager.replaceCredential(
                    accountID: account.id,
                    credential: credential
                )
            }
            try manager.updateThresholds(
                accountID: account.id,
                thresholds: thresholds
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// An empty field means the threshold is unset. Invalid text or an invalid
    /// pair reports an error and prevents any save.
    private func validatedThresholds() -> AccountThresholds? {
        switch ThresholdInput.parseThresholds(
            warningText: warningThresholdText,
            criticalText: criticalThresholdText,
            kind: kind
        ) {
        case let .success(thresholds):
            return thresholds
        case .failure:
            errorMessage = UIStrings.invalidThreshold
            return nil
        }
    }
}

private struct LabeledValue: View {
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            fieldLabel(title)
            Spacer(minLength: 12)
            Text(value)
                .font(.system(size: 11.5))
                .foregroundStyle(UITheme.textPrimary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            UITheme.control.opacity(0.55),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
    }
}

private struct LabeledMenu<SelectionValue: Hashable, Content: View>: View {
    let title: String
    @Binding var selection: SelectionValue
    let content: Content

    init(
        title: String,
        selection: Binding<SelectionValue>,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self._selection = selection
        self.content = content()
    }

    var body: some View {
        HStack(spacing: 12) {
            fieldLabel(title)
            Spacer(minLength: 12)
            Picker(title, selection: $selection) {
                content
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .fixedSize()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            UITheme.control,
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
    }
}

private struct ThemedTextField: View {
    let title: String
    @Binding var text: String
    var isSecure = false

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            fieldLabel(title)
            Group {
                if isSecure {
                    SecureField(title, text: $text)
                } else {
                    TextField(title, text: $text)
                }
            }
            .textFieldStyle(.plain)
            .font(.system(size: 11.5))
            .foregroundStyle(UITheme.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                UITheme.control,
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(UITheme.hairline, lineWidth: 1)
            )
        }
    }
}

private func formSectionTitle(_ title: String) -> some View {
    Text(title)
        .font(.system(size: 10.5, weight: .semibold))
        .tracking(0.5)
        .foregroundStyle(UITheme.textSecondary)
}

private func fieldLabel(_ title: String) -> some View {
    Text(title)
        .font(.system(size: 10))
        .foregroundStyle(UITheme.textTertiary)
}
