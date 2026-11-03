# AI Account Balance Monitor

A macOS menu bar and floating-panel app that shows the remaining prepaid balance of AI provider accounts. The domain is the small set of concepts needed to answer: "how much credit is left on each of my AI accounts, and how fresh is that answer?"

## Language

### Providers and accounts

**Provider（厂商）**:
An AI service company whose account Balance or Quota is exposed through a query API. v2 supports DeepSeek, Moonshot (Kimi), and OpenRouter. SiliconFlow is legacy-only: old Accounts remain decodable but are not polled.
_Avoid_: Model, vendor, platform, channel

**Account（账户）**:
A single labeled credential for a Provider, with an Account Kind and optional Thresholds. A Provider may have several Accounts; each Account is polled and displayed independently.
_Avoid_: Key, user, profile, wallet

**Account Kind（账户类型）**:
The metric family an Account belongs to: Balance（充值账户）or Quota（订阅账户）. It is chosen when the Account is added and cannot be changed without deleting and re-adding the Account. Moonshot supports both kinds: Balance uses a Moonshot open-platform key, and Quota is the Kimi Code subscription product. A Points kind is reserved but not shipped in v2.
_Avoid_: Plan, tier, category, subscription mode

**Unsupported Provider（不可查厂商）**:
A Provider with no direct personal query path for Balance or Quota, such as OpenAI, Anthropic, or Google Gemini. Not represented in the v2 UI.
_Avoid_: Manual provider, unavailable provider

**Region（区域）**:
An independently credentialed deployment area of a Provider, such as domestic China versus international. A credential is valid only in its Region. v2 exposes this for Moonshot.
_Avoid_: Endpoint, environment, zone

### Values

**Balance（余额）**:
The prepaid credit remaining on an Account, as reported by its Provider. It is not consumption and not a quota.
_Avoid_: Credit used, quota, remaining usage

**Spend（消费）**:
Money consumed on an Account over a period, as reported by some Providers. A different Metric from Balance; never displayed as a Balance.
_Avoid_: Balance, usage

**Quota（额度）**:
A usage allowance reported by a Provider, with a limit, a remaining amount, and a reset time. A different Metric from Balance; never displayed as a Balance. v2 reports Quota for Kimi Code subscription Accounts.
_Avoid_: Balance, allowance, remaining usage

**Metric（指标）**:
The kind of value a Snapshot reports. v2 reports Balance and Quota; Spend and Points are deferred.
_Avoid_: Value, number

**Balance Snapshot（余额快照）**:
The result of one balance query for one Account at one point in time: the Balance, its currency, availability, and the fetch timestamp.
_Avoid_: Reading, sample, record, entry

**Quota Snapshot（额度快照）**:
The result of one quota query for one Account at one point in time: the limit, remaining amount, used ratio, reset time, and fetch timestamp.
_Avoid_: Balance Snapshot, usage record

### Freshness

**Polling Interval（轮询间隔）**:
The time between automatic balance queries. Defaults to five minutes and is configurable from one to sixty minutes.
_Avoid_: Refresh rate, frequency

**Stale（已过期）**:
A Snapshot older than three Polling Intervals without a successful refresh. A Stale row keeps showing the last known value, marked as Stale.
_Avoid_: Offline, outdated, error

### Health and thresholds

**Threshold（阈值）**:
A user-set line that changes an Account's Health. A Balance Account uses two optional currency amounts: 预警线 (warning) and 紧急线 (critical). A Quota Account uses two optional remaining percentages. An Account with no Threshold is Unset.
_Avoid_: Alert level, limit, cutoff

**Health（健康状态）**:
The state derived from an Account's latest successful Snapshot and its Thresholds: 正常 (normal), 预警 (warning), 紧急 (critical), or 未设置 (unset). Stale and error are separate states, not Health values. Provider Health is the worst Account Health.
_Avoid_: Status, state, balance health
