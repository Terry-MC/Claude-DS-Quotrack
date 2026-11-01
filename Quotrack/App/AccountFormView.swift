import SwiftUI

/// Collects Provider, Region when applicable, label, credential, and the
/// optional low-Balance warning when adding an Account; when editing, it shows
/// identity read-only and collects a new label, an optional credential
/// replacement, and the threshold. A saved credential is never read back into
/// the field, and the threshold is off by default.
@MainActor
struct AccountFormView: View {
    enum Mode {
        case add
        case edit(Account)
    }

    let mode: Mode
    let manager: AccountManager

    @Environment(\.dismiss) private var dismiss
    @State private var provider: Provider
    @State private var region: Region
    @State private var label: String
    @State private var credential = ""
    @State private var lowBalanceWarningEnabled: Bool
    @State private var lowBalanceThresholdText: String
    @State private var errorMessage: String?

    init(mode: Mode, manager: AccountManager) {
        self.mode = mode
        self.manager = manager
        switch mode {
        case .add:
            _provider = State(initialValue: .deepSeek)
            _region = State(initialValue: .domestic)
            _label = State(initialValue: "")
            _lowBalanceWarningEnabled = State(initialValue: false)
            _lowBalanceThresholdText = State(initialValue: "")
        case let .edit(account):
            _provider = State(initialValue: account.provider)
            _region = State(initialValue: account.region ?? .domestic)
            _label = State(initialValue: account.label)
            _lowBalanceWarningEnabled = State(initialValue: account.lowBalanceThreshold != nil)
            _lowBalanceThresholdText = State(
                initialValue: account.lowBalanceThreshold?.description ?? ""
            )
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.title3.weight(.semibold))

            Form {
                if case .add = mode {
                    Picker("厂商", selection: $provider) {
                        ForEach(Provider.allCases, id: \.self) { provider in
                            Text(provider.displayName).tag(provider)
                        }
                    }
                } else {
                    LabeledContent("厂商", value: provider.displayName)
                }

                if provider.supportsRegion {
                    if case .add = mode {
                        Picker("区域", selection: $region) {
                            ForEach(Region.allCases, id: \.self) { region in
                                Text(region.displayName).tag(region)
                            }
                        }
                    } else {
                        LabeledContent("区域", value: region.displayName)
                    }
                }

                TextField("标签", text: $label)
                SecureField(credentialFieldLabel, text: $credential)

                Section(UIStrings.lowBalanceWarningTitle) {
                    Toggle(UIStrings.lowBalanceWarningToggle, isOn: $lowBalanceWarningEnabled)
                    if lowBalanceWarningEnabled {
                        TextField(UIStrings.lowBalanceThresholdLabel, text: $lowBalanceThresholdText)
                    }
                    Text(UIStrings.lowBalanceThresholdHint)
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
                Button("保存", action: save)
                    .keyboardShortcut(.defaultAction)
                    .disabled(label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 440)
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

    private func save() {
        guard let threshold = validatedThreshold() else {
            return
        }
        do {
            switch mode {
            case .add:
                let account = try manager.addAccount(
                    provider: provider,
                    region: provider.supportsRegion ? region : nil,
                    label: label,
                    credential: credential
                )
                if let threshold {
                    try manager.updateLowBalanceThreshold(
                        accountID: account.id,
                        threshold: threshold
                    )
                }
            case let .edit(account):
                try manager.updateLabel(accountID: account.id, label: label)
                if !credential.isEmpty {
                    try manager.replaceCredential(
                        accountID: account.id,
                        credential: credential
                    )
                }
                try manager.updateLowBalanceThreshold(
                    accountID: account.id,
                    threshold: threshold
                )
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Returns `nil` both for "off" and for an invalid entry; the error
    /// message distinguishes the invalid case, and no save happens then.
    private func validatedThreshold() -> Decimal?? {
        guard lowBalanceWarningEnabled else {
            return .some(nil)
        }
        let normalized = lowBalanceThresholdText
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Decimal(string: normalized), value > 0 else {
            errorMessage = UIStrings.invalidThreshold
            return nil
        }
        return .some(value)
    }
}
