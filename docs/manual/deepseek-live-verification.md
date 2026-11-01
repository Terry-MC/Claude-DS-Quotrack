# DeepSeek adapter live verification

The adapter tests use recorded fixture responses and a stub transport; they
never contact DeepSeek. Run this manual check after changing `DeepSeekAdapter`,
`URLSessionTransport`, or the live wiring. It requires the user's own DeepSeek
API key. **Never** put the key in a fixture, a commit, an issue, a shell
command that is saved to history, or an application log. Quotrack stores it
only in the macOS Keychain.

## Contract verified 2026-11-01

Source: <https://api-docs.deepseek.com/api/get-user-balance>.

- `GET https://api.deepseek.com/user/balance`
- `Authorization: Bearer <API_KEY>`
- Response: `is_available` (boolean) and `balance_infos` (array of objects with
  `currency`, `total_balance`, `granted_balance`, and `topped_up_balance`).
  Amounts are JSON strings; `currency` is `CNY` or `USD`.

Re-verify this page before changing the endpoint, headers, or field names.

## Preconditions

- Build and run the app from Xcode, or:
  `xcodebuild build -project Quotrack.xcodeproj -scheme Quotrack -destination 'platform=macOS' -derivedDataPath .build/DerivedData`
- Launch without `--mock`. Live mode is the default.
- Have the DeepSeek key available to paste once. Do not save it anywhere else.

## Steps and expected results

1. **Add the Account.** From the menu bar open onboarding (or 设置… ›
   添加账户…), choose DeepSeek, enter a label such as `DeepSeek 个人`, paste the
   key, and submit.
   - The connection test succeeds and the Account is saved.
   - The key is not shown again after saving and does not appear in
     `accounts.json` or `snapshots.json`.

2. **Compare the Balance.** Open the floating panel and compare the row's
   Balance and currency with the DeepSeek console (<https://platform.deepseek.com>).
   - The amounts match and the currency is the Provider's original currency
     (`¥` for CNY, `$` for USD); nothing is converted or summed.
   - The row is fresh and the relative last-updated time is recent.

3. **Check the breakdown.** Expand the row.
   - 赠送余额 (`granted_balance`) and 充值余额 (`topped_up_balance`) match the
     console, and the full-precision Balance matches `total_balance`.

4. **Refresh.** Use the per-Account refresh action.
   - The fetch time advances and the Balance remains correct.

5. **Relaunch.** Quit Quotrack and launch it again.
   - The last Snapshot is shown immediately (marked Stale when older than three
     Polling Intervals) and is replaced by the live Balance after refresh.

6. **Authentication failure.** Replace the Account's credential with an invalid
   string through 编辑账户… › 替换凭证.
   - The next refresh shows 认证失败，请检查 API 密钥。 and no key text is
     displayed anywhere.
   - Restore the real key; the next refresh succeeds.

7. **Unavailable account.** If the console reports the account as unavailable
   (for example a zero Balance), the row shows 不可用 rather than 错误 and keeps
   the last known Balance. This state is also covered automatically by
   `DeepSeekAdapterTests.anUnavailableBalanceIsShownAsUnavailableInsteadOfAnError`.

8. **Log check.** In Console.app, filter on the Quotrack process during a
   refresh.
   - No request header, credential, or response body containing a key is
     logged. The adapter does not log requests.

## Status

- Automated fixture coverage: complete (`DeepSeekAdapterTests`,
  `DeepSeekWiringTests`, `URLSessionTransportTests`).
- Live verification with a real key: **pending** until a key is supplied in the
  environment or entered by the user during a manual run.
