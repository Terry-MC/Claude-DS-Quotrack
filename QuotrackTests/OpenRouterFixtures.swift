/// Recorded OpenRouter credits responses used by adapter tests. The shape
/// comes from https://openrouter.ai/docs/api-reference/get-credits (verified
/// 2026-11-01): `data.total_credits` and `data.total_usage` are JSON numbers
/// and the Balance is their difference in USD.
enum OpenRouterFixtures {
    static let success = """
    {
      "data": {
        "total_credits": 100.5,
        "total_usage": 25.75
      }
    }
    """

    /// A normal inference key is authenticated but not allowed to read the
    /// credits endpoint; only management keys can.
    static let inferenceKeyForbidden = """
    {
      "error": {
        "code": 403,
        "message": "Only management keys can perform this operation"
      }
    }
    """
}
