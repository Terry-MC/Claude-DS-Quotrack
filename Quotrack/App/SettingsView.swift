import SwiftUI

/// The minimal Settings surface for ticket #8: an Account list with add, edit,
/// and delete. The full Settings surface and onboarding are ticket #9.
@MainActor
struct SettingsView: View {
    let manager: AccountManager

    @State private var sheet: AccountSheet?
    @State private var accountPendingDeletion: Account?
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if manager.accounts.isEmpty {
                ContentUnavailableView(
                    "尚未添加账户",
                    systemImage: "person.crop.circle.badge.plus",
                    description: Text("添加一个账户以开始监控余额。")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(manager.accounts) { account in
                        AccountRow(
                            account: account,
                            onEdit: { sheet = .edit(account) },
                            onDelete: {
                                errorMessage = nil
                                accountPendingDeletion = account
                            }
                        )
                    }
                }
                .listStyle(.inset)
            }

            Divider()

            HStack(spacing: 12) {
                Button("添加账户…") {
                    errorMessage = nil
                    sheet = .add
                }
                Spacer(minLength: 0)
                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .lineLimit(1)
                }
            }
            .padding(12)
        }
        .frame(minWidth: 460, minHeight: 320)
        .sheet(item: $sheet) { sheet in
            AccountFormView(mode: sheet.mode, manager: manager)
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
        .padding(.vertical, 4)
    }

    private var detailText: String {
        if let region = account.region {
            return "\(account.provider.displayName) · \(region.displayName)"
        }
        return account.provider.displayName
    }
}
