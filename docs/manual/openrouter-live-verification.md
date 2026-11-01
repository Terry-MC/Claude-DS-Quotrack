# OpenRouter adapter live verification

The adapter tests use recorded fixture responses and a stub transport; they
never contact OpenRouter. Run this manual check after changing
`OpenRouterAdapter`, `URLSessionTransport`, or the live wiring. It requires the
user's own OpenRouter **management key**. **Never** put the key in a fixture, a
commit, an issue, a shell command that is saved to history, or an application
log. Quotrack stores it only in the macOS Keychain.

## Contract verified 2026-11-01

Source: <https://openrouter.ai/docs/api-reference/get-credits>.

- `GET https://openrouter.ai/api/v1/credits`
- `Authorization: Bearer <MANAGEMENT_KEY>`
- Response: `{ "data": { "total_credits": <number>, "total_usage": <number> } }`.
  Amounts are JSON numbers, not strings, and are denominated in USD. The
  Balance is `total_credits - total_usage`.
- A normal inference key is authenticated but not authorized for this endpoint
  and receives HTTP 403 ("Only management keys can perform this operation").

Re-verify this page before changing the endpoint, headers, or field names.

## Endpoint reachability (no credential)

On 2026-11-01 a credential-free request to the endpoint returned HTTP 401 with
the body `{"error":{"message":"No cookie auth credentials found","code":401}}`.
This confirms the URL is live. Because OpenRouter requires a management key,
both 401 and 403 map to `permission` and show the management-key message; the
401 response does not exercise a successful credits response.

## Preconditions

- Build and run the app from Xcode, or:
  `xcodebuild build -project Quotrack.xcodeproj -scheme Quotrack -destination 'platform=macOS' -derivedDataPath .build/DerivedData`
- Launch without `--mock`. Live mode is the default.
- Create an OpenRouter management key at <https://openrouter.ai/settings/keys>
  and have it available to paste once. Do not save it anywhere else. A
  management key is more privileged than an inference key, so use a dedicated
  one and revoke it when done if it is no longer needed.

## Steps and expected results

1. **Add the Account.** From the menu bar open onboarding (or 设置… ›
   添加账户…), choose OpenRouter, enter a label such as `OpenRouter 管理`, paste
   the management key, and submit.
   - The form shows the management-key warning before saving.
   - The connection test succeeds and the Account is saved.
   - The key is not shown again after saving and does not appear in
     `accounts.json` or `snapshots.json`.

2. **Compare the Balance.** Open the floating panel and compare the row's
   Balance with the OpenRouter credits page
   (<https://openrouter.ai/settings/credits>).
   - The amount is `total_credits - total_usage`, shown as `$` with two
     decimals; nothing is converted or summed.
   - The row is fresh and the relative last-updated time is recent.

3. **Check the breakdown.** Expand the row.
   - 总额 (`total_credits`) and 消费 (`total_usage`) match the credits page,
     and the full-precision Balance is their difference.

4. **Refresh.** Use the per-Account refresh action.
   - The fetch time advances and the Balance remains correct.

5. **Relaunch.** Quit Quotrack and launch it again.
   - The last Snapshot is shown immediately (marked Stale when older than three
     Polling Intervals) and is replaced by the live Balance after refresh.

6. **Normal inference key (403).** Add a second Account with a normal inference
   key, or replace an Account's credential with one through 编辑账户… ›
   替换凭证.
   - The connection test fails, nothing is saved, and the row shows
     权限不足，OpenRouter 需要管理密钥。
   - The message must say a management key is required, not a generic
     permission error.

7. **Invalid credential (401).** Replace the credential with an invalid string.
   - The next refresh shows 权限不足，OpenRouter 需要管理密钥。 and no key text
     is displayed anywhere.
   - Restore the real management key; the next refresh succeeds.

8. **Log check.** In Console.app, filter on the Quotrack process during a
   refresh.
   - No request header, credential, or response body containing a key is
     logged. The adapter does not log requests.

## Status

- Automated fixture coverage: complete (`OpenRouterAdapterTests`, the
  parameterized `AdapterWiringTests`, and `URLSessionTransportTests`).
- Endpoint reachability and the 401 path: verified without a key.
- The 403 inference-key path: fixture-only; no inference key was supplied.
- Live verification with a real management key: **pending** until the user
  supplies one in the environment or enters one during a manual run.
- The adapter remains **unverified** against a live account until then.
