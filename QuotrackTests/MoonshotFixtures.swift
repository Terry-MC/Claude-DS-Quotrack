/// Recorded Moonshot (Kimi) balance responses used by adapter tests. The shape
/// comes from the official balance docs (verified 2026-11-01):
/// `GET /v1/users/me/balance` with Bearer auth returns `data` containing
/// numeric `available_balance`, `voucher_balance`, and `cash_balance`.
enum MoonshotFixtures {
    static let success = """
    {
      "code": 0,
      "data": {
        "available_balance": 49.58894,
        "voucher_balance": 46.58893,
        "cash_balance": 3.00001
      },
      "scode": "0x0",
      "status": true
    }
    """
}
