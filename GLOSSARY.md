# AI Account Balance Monitor

A macOS menu bar and floating-panel app that shows the remaining prepaid balance of AI provider accounts. The domain is the small set of concepts needed to answer: "how much credit is left on each of my AI accounts, and how fresh is that answer?"

## Language

### Providers and accounts

**Provider（厂商）**:
An AI service company whose account balance is exposed through a documented API. v1 supports DeepSeek, Moonshot (Kimi), SiliconFlow, and OpenRouter.
_Avoid_: Model, vendor, platform, channel

**Account（账户）**:
A single labeled credential for a Provider. A Provider may have several Accounts; each Account is polled and displayed independently.
_Avoid_: Key, user, profile, wallet

**Unsupported Provider（不可查厂商）**:
A Provider with no documented individual balance API, such as OpenAI, Anthropic, or Google Gemini. Not represented in the v1 UI.
_Avoid_: Manual provider, unavailable provider

**Region（区域）**:
An independently credentialed deployment area of a Provider, such as domestic China versus international. A credential is valid only in its Region. v1 exposes this for Moonshot and SiliconFlow.
_Avoid_: Endpoint, environment, zone

### Values

**Balance（余额）**:
The prepaid credit remaining on an Account, as reported by its Provider. It is not consumption and not a quota.
_Avoid_: Credit used, quota, remaining usage

**Spend（消费）**:
Money consumed on an Account over a period, as reported by some Providers. A different Metric from Balance; never displayed as a Balance.
_Avoid_: Balance, usage

**Quota（配额）**:
A usage limit or remaining allowance imposed by a Provider. A different Metric from Balance; never displayed as a Balance.
_Avoid_: Balance, limit

**Metric（指标）**:
The kind of value a Balance Snapshot reports. v1 reports only Balance; Spend and Quota are deferred to v2.
_Avoid_: Value, number

**Balance Snapshot（余额快照）**:
The result of one balance query for one Account at one point in time: the Balance, its currency, availability, and the fetch timestamp.
_Avoid_: Reading, sample, record, entry

### Freshness

**Polling Interval（轮询间隔）**:
The time between automatic balance queries. Defaults to five minutes and is configurable from one to sixty minutes.
_Avoid_: Refresh rate, frequency

**Stale（已过期）**:
A Balance Snapshot older than three Polling Intervals without a successful refresh. A Stale row keeps showing the last known Balance, marked as Stale.
_Avoid_: Offline, outdated, error
