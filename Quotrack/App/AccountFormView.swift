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
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.title3.weight(.semibold))

            Form {
                if case .add = mode {
                    Picker("厂商", selection: providerSelection) {
                        ForEach(Provider.addableCases, id: \.self) { provider in
                            Text(provider.displayName).tag(provider)
                        }
                    }
                } else {
                    LabeledContent("厂商", value: provider.displayName)
                }

                if provider.supportsRegion {
                    if case .add = mode {
                        Picker("区域", selection: regionSelection) {
                            ForEach(Region.allCases, id: \.self) { region in
                                Text(region.displayName).tag(region)
                            }
                        }
                    } else {
                        LabeledContent("区域", value: region.displayName)
                    }
                }

                if case .add = mode, provider.supportedKinds.count > 1 {
                    Picker(UIStrings.accountKindLabel, selection: $kind) {
                        ForEach(provider.supportedKinds, id: \.self) { kind in
                            Text(kind.displayName).tag(kind)
                        }
                    }
                    .onChange(of: kind) { _, newKind in
                        applyDefaults(for: newKind)
                    }
                } else {
                    LabeledContent(UIStrings.accountKindLabel, value: kind.displayName)
                }

                TextField("标签", text: $label)
                SecureField(credentialFieldLabel, text: $credential)
                if let warning = AccountFormPresentation.credentialWarning(for: provider) {
                    Text(warning)
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Section(UIStrings.healthThresholdsTitle) {
                    TextField(warningFieldLabel, text: $warningThresholdText)
                    TextField(criticalFieldLabel, text: $criticalThresholdText)
                    Text(thresholdHint)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if kind == .balance {
                        Text(UIStrings.thresholdCurrencyHint)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .formStyle(.grouped)

            if case .edit = mode {
                Text("已保存的凭证不会显示。留空则保持现有凭证不变。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button("取消", role: .cancel) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                Button(saveButtonTitle, action: save)
                    .keyboardShortcut(.defaultAction)
                    .disabled(
                        label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            || isSaving
                    )
            }
        }
        .padding(20)
        .frame(width: 440)
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
                } else if newProvider.defaultCurrency(for: region) != oldCurrency {
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
                if provider.defaultCurrency(for: newRegion) != oldCurrency {
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
                provider: draft.provider
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
