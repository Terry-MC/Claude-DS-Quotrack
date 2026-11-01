import SwiftUI

/// Collects Provider, Region when applicable, label, and credential when
/// adding an Account; when editing, it shows identity read-only and collects
/// a new label plus an optional credential replacement. A saved credential is
/// never read back into the field.
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
    @State private var errorMessage: String?

    init(mode: Mode, manager: AccountManager) {
        self.mode = mode
        self.manager = manager
        switch mode {
        case .add:
            _provider = State(initialValue: .deepSeek)
            _region = State(initialValue: .domestic)
            _label = State(initialValue: "")
        case let .edit(account):
            _provider = State(initialValue: account.provider)
            _region = State(initialValue: account.region ?? .domestic)
            _label = State(initialValue: account.label)
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
        .frame(width: 420)
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
        do {
            switch mode {
            case .add:
                try manager.addAccount(
                    provider: provider,
                    region: provider.supportsRegion ? region : nil,
                    label: label,
                    credential: credential
                )
            case let .edit(account):
                try manager.updateLabel(accountID: account.id, label: label)
                if !credential.isEmpty {
                    try manager.replaceCredential(
                        accountID: account.id,
                        credential: credential
                    )
                }
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
