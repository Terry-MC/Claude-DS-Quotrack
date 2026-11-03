# v2 monitors Balance and Quota with user-set thresholds, using direct personal APIs only

v2 extends Quotrack from a Balance viewer into a per-Account health monitor. The v2 UI prototype (reviewed 2026-11-03) introduced Provider grouping, Account Kinds, progress bars, a docked side tab, and notifications. The prototype's progress bars assumed a "total top-up" baseline that most Providers do not expose. On 2026-11-03 the scope was resolved as follows:

1. Balance accounts use the current Balance plus two user-set thresholds; there is no total-top-up or used-percentage baseline.
2. Subscription (Quota) and top-up (Balance) accounts are separate Account Kinds, chosen when an Account is added.
3. SiliconFlow is dropped.
4. Only Providers with a currently available individual query path are supported.
5. Only personal-level accounts are in scope.

Research on 2026-11-03 found direct personal credentials for DeepSeek, Moonshot (Balance and Kimi Code Quota), and OpenRouter. SiliconFlow's `/v1/user/info` was reported to stop serving on 2026-08-14 with no replacement. WorkBuddy, Claude Pro/Max, ChatGPT/Codex, Gemini CLI, and SuperGrok require reading desktop or CLI OAuth state and are deferred. OpenAI, Anthropic, and Gemini spend requires organization-level Admin or cloud credentials and is outside the personal-level v2.

## Decision

- v2 supports two Account Kinds: Balance (充值账户) and Quota (订阅账户). A Points kind is reserved but not shipped in v2.0.
- Balance accounts show the current Balance and two optional per-Account thresholds: warning (预警线) and critical (紧急线), in the Account's currency. They do not show a synthetic "used %" or "total top-up" progress bar. OpenRouter's total credits and usage appear only as expanded detail, not as the health gauge.
- Quota accounts show remaining quota and two optional thresholds expressed as remaining percentage. They are the only kind with a progress bar, because the Provider supplies a real denominator.
- Health states are normal, warning, critical, and unset. Stale and error are independent states. Provider health is the worst Account health, never a sum of thresholds.
- v2 Providers: DeepSeek (Balance), Moonshot (Balance and Quota; the Quota kind is the Kimi Code product, using an `sk-kimi-…` key and marked experimental because its endpoint is undocumented), and OpenRouter (Balance; management key).
- SiliconFlow is removed from the add-account list. Existing SiliconFlow Accounts remain decodable, show as unsupported, stop polling, and can be deleted.
- v2 reads only direct personal API credentials: API keys, personal management keys, and personal Admin keys where applicable. It does not read browser cookies, desktop containers, OAuth files, or CLI login state.
- Local-bridge integrations (WorkBuddy, Claude Pro/Max, ChatGPT/Codex, Gemini CLI, SuperGrok) are deferred to a separate ADR and a default-off, source-available, least-privilege bridge.
- Organization-level Spend/Quota (OpenAI Admin API, Anthropic Admin API, Google Cloud Billing, Alibaba BSS, Volcano Ark) is out of scope for v2.0. A future Spend kind requires a separate ADR.
- Notifications fire only on health-state transitions. Stale and error do not trigger Balance alerts. Hysteresis prevents flapping.
- Existing Accounts migrate with `kind = balance`; the old low-Balance threshold becomes the warning threshold; the critical threshold is unset.

## Considered Options

- **Keep the prototype's total-top-up / used% bars for every Provider** — rejected: only OpenRouter exposes a lifetime total; DeepSeek and Moonshot would require an invented denominator.
- **Normalize Balance, Quota, and Spend into one progress bar** — rejected: contradicts ADR-0001; they are different Metric kinds with different data sources and health rules.
- **Include a local bridge in v2.0** — rejected for now: it adds an unsandboxed, high-privilege component, several undocumented endpoints, and significant maintenance.
- **Hard-remove SiliconFlow from the Provider enum** — rejected: v1 persisted Accounts as JSON; deleting the enum case would break decoding. Keep a legacy case marked unsupported.
- **Use used-percentage thresholds for Quota accounts** — rejected: remaining percentage matches the "current balance" semantics and is easier to reason about.
- **Let users paste OAuth tokens into Quotrack** — rejected: it puts high-value tokens into the app and contradicts the credential boundary.

## Consequences

- v2 can ship without a bridge, browser integration, or organization credentials.
- Balance accounts no longer show "used %". Users set thresholds or inspect OpenRouter's expanded details.
- WorkBuddy, Claude Pro/Max, ChatGPT/Codex, Gemini CLI, and SuperGrok are not available in v2.0; the README and Settings must say so.
- SiliconFlow Accounts become unsupported; v1 users see an error state rather than a live Balance.
- Moonshot is the only Provider with both kinds. Its Quota kind is the Kimi Code product and is experimental; if its endpoint changes, that kind has no working product.
- OpenRouter requires a management key, which is higher privilege than an inference key; the add-account form must explain this.
- The Points and Spend kinds are not shipped; the data model leaves room for them but v2.0 adds no UI or adapter.

## References

- ADR-0001: v1 only supports Providers with a documented individual Balance API.
- v1 spec: #1.
- v2 spec: issue #17.
- UI prototype reviewed 2026-11-03.
