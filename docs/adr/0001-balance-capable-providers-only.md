# v1 only supports providers with a documented individual balance API

v1 of Quotrack monitors only Providers that expose a documented API for an individual account's prepaid Balance. Research on 2026-11-01 found that only DeepSeek, Moonshot, SiliconFlow, OpenRouter, and xAI return a real Balance; OpenAI, Anthropic, Google Gemini, and Mistral expose Spend or Quota at best, and Anthropic's Admin API is unavailable to individual accounts. v1 therefore supports DeepSeek, Moonshot, SiliconFlow, and OpenRouter; Spend and Quota are deferred to v2.

## Considered Options

- **Include Spend/Quota for OpenAI, Anthropic, Gemini** — rejected for v1: mixing Metric kinds in one "balance" window would mislead, and Anthropic individual accounts cannot access the data at all.
- **Use undocumented console endpoints** (e.g. Zhipu) — rejected: unstable and unverifiable.
- **Require cloud AK/SK** for Alibaba Bailian and Volcano Ark — deferred: larger security surface, not needed for the initial providers.
- **xAI** — deferred: it works, but needs a management key plus `team_id` and is not in daily use.

## Consequences

- The app cannot show an OpenAI or Anthropic balance; users of those providers see no row for them.
- OpenRouter exposes a real Balance that covers many models, but requires a management key rather than an inference key.
- Adding a Provider later means first verifying a documented individual Balance API, not merely that the Provider exists.
