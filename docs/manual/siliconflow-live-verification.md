# SiliconFlow adapter live verification

**Status: unverified.** The adapter is written against the documented contract
and its fixture tests pass, but no real SiliconFlow credential has been used.
Run this manual check after changing `SiliconFlowAdapter`,
`URLSessionTransport`, or the live wiring, and update the status once a real
key succeeds. It requires the user's own SiliconFlow key. **Never** put the key
in a fixture, a commit, an issue, a shell command that is saved to history, or
an application log. Quotrack stores it only in the macOS Keychain.

## Contract recorded 2026-11-01

Source: the official OpenAPI document
<https://raw.githubusercontent.com/siliconflow/siliconcloud/main/openapi.yaml>
and the two live platforms.

- Domestic: `GET https://api.siliconflow.cn/v1/user/info`
- International: `GET https://api.siliconflow.com/v1/user/info`
- Auth: `Authorization: Bearer <API_KEY>`
- Response: `data.balance` (granted portion), `data.chargeBalance` (charged
  portion), and `data.totalBalance` (their total). The three amounts are JSON
  strings. The response also carries `code`, `message`, `status`, but only the
  three `data` fields above are used.
- Currency comes from the Region, not the response: CNY for domestic and USD
  for international. SiliconFlow keys are region-locked, so an authentication
  failure is the expected symptom of a key sent to the wrong Region.
- The OpenAPI operation is not marked deprecated, and both hosts answered on
  2026-11-01.

### Spec discrepancy

The v1 spec describes `chargeBalance` as the granted portion. The official
OpenAPI document instead defines `balance` as the granted portion and
`chargeBalance` as the charged portion, with `totalBalance` as their total. The
adapter follows the OpenAPI contract and keeps the wire field names unchanged:
`.granted` maps to `data.balance` and `.toppedUp` maps to `data.chargeBalance`.
The spec wording should be corrected; no adapter change is pending. The manual
comparison below is the authority for the eventual live check.

Re-verify this contract before changing the endpoint, headers, or field names.

## Endpoint reachability (no credential)

On 2026-11-01 a credential-free request to each endpoint returned HTTP 401 with
the body `{"code":30014,"data":null,"message":"Token is invalid."}`. This
confirms both URLs are live and that a missing or invalid key follows the 401
path the adapter maps to `authentication`; it does not exercise a successful
balance response.

## Preconditions

- Build and run the app from Xcode, or:
  `xcodebuild build -project Quotrack.xcodeproj -scheme Quotrack -destination 'platform=macOS' -derivedDataPath .build/DerivedData`
- Launch without `--mock`. Live mode is the default.
- Have a SiliconFlow key for the Region under test available to paste once. Do
  not save it anywhere else. A domestic key works only against `siliconflow.cn`
  and an international key only against `siliconflow.com`.

## Steps and expected results

1. **Add a domestic Account.** From the menu bar open onboarding (or 设置… ›
   添加账户…), choose SiliconFlow, choose 国内, enter a label such as
   `硅基流动 个人`, paste a domestic key, and submit.
   - The connection test succeeds and the Account is saved.
   - The key is not shown again after saving and does not appear in
     `accounts.json` or `snapshots.json`.

2. **Compare the Balance.** Open the floating panel and compare the row's
   Balance and currency with the SiliconFlow console (<https://cloud.siliconflow.cn>).
   - The row shows `¥`, and the amount matches `totalBalance` in the console.
   - Nothing is converted or summed.

3. **Check the breakdown.** Expand the row.
   - 赠送余额 (`data.balance`) and 充值余额 (`data.chargeBalance`) match the
     console. The full-precision Balance matches `data.totalBalance`.

4. **Check the international Region.** If an international key is available,
   add a second Account with 国际 and the key from
   <https://cloud.siliconflow.com>.
   - The request goes to `api.siliconflow.com`, the row shows `$`, and the
     amounts match the international console.
   - Using the domestic key for the international Account shows 认证失败，请检查
     API 密钥，并确认所选区域与凭证匹配。; the Region is the first thing to
     check.

5. **Refresh.** Use the per-Account refresh action.
   - The fetch time advances and the Balance remains correct.

6. **Relaunch.** Quit Quotrack and launch it again.
   - The last Snapshot is shown immediately (marked Stale when older than three
     Polling Intervals) and is replaced by the live Balance after refresh.

7. **Authentication failure.** Replace the Account's credential with an invalid
   string through 编辑账户… › 替换凭证.
   - The next refresh shows 认证失败，请检查 API 密钥，并确认所选区域与凭证匹配。
     and no key text is displayed anywhere.
   - Restore the real key; the next refresh succeeds.

8. **Permission and rate-limit mapping.** These are covered automatically by
   `SiliconFlowAdapterTests` with a stub transport; no manual step can force
   them reliably.

9. **Log check.** In Console.app, filter on the Quotrack process during a
   refresh.
   - No request header, credential, or response body containing a key is
     logged. The adapter does not log requests.

## Status

- Automated fixture coverage: complete (`SiliconFlowAdapterTests` and the
  parameterized `AdapterWiringTests`). Tests use the stub transport and never
  touch the network.
- Endpoint reachability and the 401 path: verified without a key on 2026-11-01.
- **Live verification with a real key: unverified / pending.** No SiliconFlow
  credential was available. The adapter stays marked unverified until a real
  key is used following the steps above.
