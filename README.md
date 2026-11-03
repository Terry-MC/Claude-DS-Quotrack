# Quotrack

A macOS menu-bar app with a floating panel that shows the remaining prepaid Balance and subscription Quota of AI provider accounts in one place. Metrics are polled directly from each provider's API; credentials live in the macOS Keychain and there is no backend.

## Status

- **v1 complete** on `main` (PR #16, merge commit `7dd3b37`).
- **v2 complete** on `integration/20-24` (implementation tickets #18–#27); merge to `main` pending.
- 419 Swift Testing tests across 58 suites pass.
- Real-key live verification completed for **DeepSeek** and **Moonshot (Kimi, domestic)** in v1. **Kimi Code Quota**, **OpenRouter**, and **SiliconFlow** remain unverified against real credentials; see `docs/manual/`.
- The v1 spec (#1) and its implementation tickets (#2–#15) are closed. The v2 spec is [#17](https://github.com/Terry-MC/Claude-DS-Quotrack/issues/17); decisions are in `docs/adr/0002-threshold-based-balance-and-quota.md`.

## Features

- Native SwiftUI + AppKit: menu-bar status item, floating panel, and a right-edge dock; no Dock icon.
- Accounts grouped under collapsible Provider cards, in creation order, with per-Provider and per-Account refresh.
- Two Account Kinds: **Balance (充值账户)** and **Quota (订阅账户)**.
- DeepSeek and OpenRouter Balance Accounts; Moonshot open-platform Balance and Kimi Code Quota (experimental). SiliconFlow is legacy-only and shown as unsupported.
- Optional warning and critical thresholds per Account: currency amounts for Balance, remaining percentages for Quota.
- Health states 正常 / 预警 / 紧急 / 未设置, Provider summaries grouped by Kind and currency, and an aggregate menu-bar state where error wins over critical/warning wins over stale.
- Health-transition notifications, aggregated per poll, with an in-app toast fallback when notification permission is denied.
- Stale detection after three Polling Intervals, typed errors, and last-known values that remain visible.
- Polling with a configurable interval (5 minutes by default, 1–60), a global concurrency cap, per-Account exponential backoff, `Retry-After`, and sleep/wake handling.
- Account CRUD, first-run onboarding, connection testing before save, row details with balance breakdown and Quota windows.
- Mock mode (`--mock`) with fixtures for every Kind, Health state, error, stale state, mixed Provider, and dock state.
- Simplified Chinese UI, App Sandbox with outbound network access, no telemetry, no credential logging.

## Requirements

- macOS 26.0 or later (developed on macOS 26.6.2).
- Xcode 27.2 or later.
- XcodeGen (`brew install xcodegen`).

## Build, test, run

```bash
brew install xcodegen          # once
xcodegen generate

xcodebuild build \
  -project Quotrack.xcodeproj \
  -scheme Quotrack \
  -destination 'platform=macOS' \
  -derivedDataPath .build/DerivedData

xcodebuild test \
  -project Quotrack.xcodeproj \
  -scheme Quotrack \
  -destination 'platform=macOS' \
  -derivedDataPath .build/DerivedData

open .build/DerivedData/Build/Products/Debug/Quotrack.app
```

Mock demo:

```bash
open .build/DerivedData/Build/Products/Debug/Quotrack.app --args --mock
```

The generated `Quotrack.xcodeproj`, `.build/`, and `build/` are gitignored. `project.yml` is the source of truth for the project.

## Using the app

- **Left-click** the Quotrack icon in the menu bar to show or hide the floating panel.
- **Right-click** the icon for Settings, Launch at Login, Switch Data Source (Debug builds), and Quit.
- The dock at the right edge stays visible while the panel is hidden. Click it to open the panel; its badge counts Accounts in warning or critical.
- Add an Account from onboarding or **设置… → 添加账户…**. Choose the Account Kind first: Moonshot Balance uses an open-platform key, while Moonshot subscription uses a Kimi Code `sk-kimi-…` key. Moonshot requires a Region matching the credential; OpenRouter requires a **management key**, not an inference key.
- The panel groups Accounts into Provider cards. Collapse a card to see per-Kind Balance totals or the worst remaining Quota percentage. Click an Account row to expand the exact Balance or quota, fetch time, breakdown, error detail, and refresh action.

## Supported providers

| Provider | Kind | Credential | Region | API | Live status |
|---|---|---|---|---|---|
| DeepSeek | Balance | API key | — | `GET /user/balance` | Verified with a real key |
| Moonshot (Kimi) | Balance | API key | Domestic / International | `GET /v1/users/me/balance` | Domestic verified with a real key; international pending |
| Moonshot — Kimi Code | Quota (experimental) | `sk-kimi-…` key | Domestic / International | `GET /coding/v1/usages` | Unverified; endpoint is undocumented |
| OpenRouter | Balance | Management key | — | `GET /api/v1/credits` | Unverified (no management key) |
| SiliconFlow | Legacy only | API key | Domestic / International | none | Endpoint stopped serving; existing Accounts show as unsupported |

SiliconFlow is absent from the add-account list. Its Provider case remains only to decode v1 Accounts.

Unsupported by design: OpenAI, Anthropic, Google Gemini, Mistral, xAI, Zhipu, Alibaba Bailian, and Volcano Ark. See `docs/adr/0001-balance-capable-providers-only.md`. OpenAI/Anthropic/Gemini expose Spend or Quota rather than an individual Balance; Spend and Quota are separate Metric kinds, not Balances. WorkBuddy, Claude Pro/Max, ChatGPT/Codex, Gemini CLI, and SuperGrok are deferred because they require a local bridge; see ADR-0002.

## Where data lives

- Sandbox container: `~/Library/Containers/com.terry.quotrack/Data/Library/Application Support/com.terry.quotrack/` (`accounts.json`, `snapshots.json`, settings).
- Credentials: macOS Keychain, service `com.terry.quotrack`, account = the Account UUID.
- Credentials never appear in JSON, logs, or the Settings UI after saving.

Ad-hoc development builds use the legacy login keychain; a team-signed release can opt into the data-protection keychain via `KeychainQuery(usesDataProtectionKeychain: true)`.

## Architecture

- `Quotrack/App/` — AppKit lifecycle, status item, floating panel, SwiftUI views, Settings and onboarding windows.
- `Quotrack/Core/` — domain types, `BalanceMonitor`, provider adapters, HTTP transport, credential/snapshot/settings stores, presentation logic, sleep/wake and login-item seams.
- `QuotrackTests/` — hostless Swift Testing target compiling the core sources; fixtures and stub transports, no network or real Keychain.
- `project.yml` — XcodeGen project definition; `Quotrack.xcodeproj` is generated.

The test seams are `BalanceMonitor` plus injected `AccountProvider` adapters keyed by `(Provider, AccountKind)`, `PollingClock`, `CredentialStore`, `SnapshotStore`, and `HTTPTransport`. Provider adapters are tested with fixture responses; the monitor, Health evaluator, notification coordinator, dock presentation, and Provider grouping are tested with deterministic fakes.

## Manual verification

Provider and Keychain checks that need real credentials are documented under `docs/manual/`:

- `deepseek-live-verification.md`
- `moonshot-live-verification.md`
- `siliconflow-live-verification.md`
- `openrouter-live-verification.md`
- `keychain-smoke-test.md`

## Known limitations

- Ad-hoc signed builds change identity on rebuild, so macOS may ask for Keychain access again. Choose **始终允许** (Always Allow) and, if necessary, re-enter the credential. Team signing avoids this.
- Launch at Login is unreliable while the app runs from DerivedData. Copy `Quotrack.app` to `/Applications` for daily use.
- Kimi Code Quota, OpenRouter, and SiliconFlow have fixture coverage only; live behavior is unverified until the relevant credentials are supplied.
- The Kimi Code usage endpoint is undocumented and treated as experimental; a malformed response fails only that Account.
- Notification permission is requested on the first Health transition. If denied, Quotrack shows an in-app toast instead. Notifications are never sent for Stale or error states.
- The dock is placed on the main screen and repositions when displays change; it does not follow the pointer between displays.
- No Spend or Points Kind, Balance history/trends, OAuth/local bridge, auto-update, or distribution/notarization.

## v2 scope (delivered)

v2 turns the panel into a threshold-based health monitor. The full spec is [#17](https://github.com/Terry-MC/Claude-DS-Quotrack/issues/17); the decisions are recorded in `docs/adr/0002-threshold-based-balance-and-quota.md`.

**In scope**

- Provider grouping and collapsible cards.
- Two Account Kinds: Balance (充值账户) and Quota (订阅账户).
- Balance Accounts show the current Balance and optional 预警线 / 紧急线 thresholds in the Account currency. No synthetic total-top-up or used-percentage bar.
- Quota Accounts show remaining quota and optional remaining-percentage thresholds. Kimi Code is the only Quota product and is marked experimental.
- Health states 正常 / 预警 / 紧急 / 未设置, Provider summaries, a dock badge, and notifications on health transitions.
- Providers: DeepSeek, Moonshot (Balance and Kimi Code Quota), and OpenRouter.
- Migration: v1 Accounts become Balance; `lowBalanceThreshold` becomes `warningThreshold`; SiliconFlow Accounts become unsupported.

**Out of scope for v2**

- SiliconFlow: its balance endpoint stopped serving in 2026-08; keep it only for decoding old Accounts.
- WorkBuddy, Claude Pro/Max, ChatGPT/Codex, Gemini CLI, and SuperGrok: they require a local bridge to read desktop or CLI OAuth state.
- OpenAI/Anthropic/Gemini organization-level Spend, Google Cloud Billing, Alibaba BSS, Volcano Ark, xAI, and Zhipu.
- Points and Spend Account Kinds, history/trends, the prototype's undefined dashboard mode, and auto-update/notarization.

## Agent workflow

- Read `CLAUDE.md`, `GLOSSARY.md`, `docs/adr/0001-balance-capable-providers-only.md`, `docs/adr/0002-threshold-based-balance-and-quota.md`, and `docs/agents/*.md` first.
- Issues live in GitHub Issues; use the `gh` commands in `docs/agents/issue-tracker.md` and the `ready-for-agent` label.
- The engineering skills follow `/grilling` → `/to-spec` → `/to-tickets` → `/implement-spec`, with TDD for every ticket.
- The v2 spec is [#17](https://github.com/Terry-MC/Claude-DS-Quotrack/issues/17). Do not reuse the closed v1 spec (#1).
