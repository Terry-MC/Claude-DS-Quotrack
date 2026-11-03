# Moonshot adapter live verification

The adapter tests use recorded fixture responses and a stub transport; they
never contact Moonshot. Run this manual check after changing `MoonshotAdapter`,
`URLSessionTransport`, or the live wiring. It requires the user's own Moonshot
(Kimi) API key. **Never** put the key in a fixture, a commit, an issue, a shell
command that is saved to history, or an application log. Quotrack stores it
only in the macOS Keychain.

## Contract verified 2026-11-01

Sources: <https://platform.kimi.com/docs/api/balance> (domestic) and
<https://platform.kimi.ai/docs/api/balance> (international).

- Domestic: `GET https://api.moonshot.cn/v1/users/me/balance`
- International: `GET https://api.moonshot.ai/v1/users/me/balance`
- `Authorization: Bearer <API_KEY>`
- Response:
  `{ "code": 0, "data": { "available_balance": ..., "voucher_balance": ...,
  "cash_balance": ... }, "scode": "0x0", "status": true }`.
  The three amounts are JSON numbers nested under `data`. The response has no
  currency field: the domestic deployment reports CNY and the international
  deployment reports USD. API keys are platform-specific; using a domestic key
  against the international endpoint (or the reverse) returns HTTP 401.

Re-verify these pages before changing the endpoint, headers, or field names.

## Endpoint reachability (no credential)

On 2026-11-01 credential-free requests to both endpoints returned HTTP 401.
This confirms the URLs are live and that a missing, invalid, or wrong-Region
key follows the 401 path the adapter maps to `authentication`; it does not
exercise a successful balance response.

## Preconditions

- Build and run the app from Xcode, or:
  `xcodebuild build -project Quotrack.xcodeproj -scheme Quotrack -destination 'platform=macOS' -derivedDataPath .build/DerivedData`
- Launch without `--mock`. Live mode is the default.
- Have the domestic or international Kimi key available to paste once. Do not
  save it anywhere else.

## Steps and expected results

1. **Add the Account.** From the menu bar open onboarding (or 设置… ›
   添加账户…), choose Moonshot (Kimi), choose the Region that matches the key
   (国内 for `api.moonshot.cn`, 国际 for `api.moonshot.ai`), enter a label such
   as `Kimi 国内`, paste the key, and submit.
   - The connection test succeeds and the Account is saved.
   - The key is not shown again after saving and does not appear in
     `accounts.json` or `snapshots.json`.

2. **Compare the Balance.** Open the floating panel and compare the row's
   Balance and currency with the Moonshot console.
   - Domestic Accounts show `¥` (CNY); international Accounts show `$` (USD).
     Nothing is converted or summed.
   - The row is fresh and the relative last-updated time is recent.

3. **Check the breakdown.** Expand the row.
   - 代金券余额 (`voucher_balance`) and 现金余额 (`cash_balance`) match the
     console, and the full-precision Balance matches `available_balance`.
   - A negative cash Balance (money owed) is displayed as reported, not clamped.

4. **Refresh.** Use the per-Account refresh action.
   - The fetch time advances and the Balance remains correct.

5. **Relaunch.** Quit Quotrack and launch it again.
   - The last Snapshot is shown immediately (marked Stale when older than three
     Polling Intervals) and is replaced by the live Balance after refresh.

6. **Region mismatch.** Add a second Account with the same key but the other
   Region and submit the connection test.
   - It fails with 认证失败，请检查 API 密钥，并确认所选区域与凭证匹配。 and no
     Account is saved. Keys are Region-locked, so the message must mention the
     Region.
   - Correct the Region; the next test succeeds.

7. **Invalid credential.** Replace the Account's credential with an invalid
   string through 编辑账户… › 替换凭证.
   - The next refresh shows the same Region-aware authentication message and no
     key text is displayed anywhere.
   - Restore the real key; the next refresh succeeds.

8. **Log check.** In Console.app, filter on the Quotrack process during a
   refresh.
   - No request header, credential, or response body containing a key is
     logged. The adapter does not log requests.

## Status

- Automated fixture coverage: complete (`MoonshotAdapterTests`,
  the parameterized `AdapterWiringTests` and `URLSessionTransportTests`).
- Endpoint reachability and the 401 path: verified without a key.
- Live verification with a real key: **pending** until a key is supplied in the
  environment or entered by the user during a manual run. No Kimi credential
  was available in the implementation environment on 2026-11-01.
