/// Recorded DeepSeek balance responses used by adapter tests. The shape comes
/// from https://api-docs.deepseek.com/api/get-user-balance (verified
/// 2026-11-01): amounts are JSON strings and `balance_infos` is an array.
enum DeepSeekFixtures {
    static let success = """
    {
      "is_available": true,
      "balance_infos": [
        {
          "currency": "CNY",
          "total_balance": "110.00",
          "granted_balance": "10.00",
          "topped_up_balance": "100.00"
        }
      ]
    }
    """

    static let unavailable = """
    {
      "is_available": false,
      "balance_infos": [
        {
          "currency": "USD",
          "total_balance": "0.00",
          "granted_balance": "0.00",
          "topped_up_balance": "0.00"
        }
      ]
    }
    """
}
