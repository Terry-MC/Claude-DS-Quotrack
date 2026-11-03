/// Recorded SiliconFlow user-info responses used by adapter tests. The shape
/// comes from the official OpenAPI document
/// (https://raw.githubusercontent.com/siliconflow/siliconcloud/main/openapi.yaml,
/// verified 2026-11-01): `data.balance`, `data.chargeBalance`, and
/// `data.totalBalance` are JSON strings.
enum SiliconFlowFixtures {
    /// Domestic Region. `balance` is the granted portion and `chargeBalance`
    /// is the charged/top-up portion; `totalBalance` is their sum.
    static let domesticSuccess = """
    {
      "code": 20000,
      "message": "OK",
      "status": true,
      "data": {
        "id": "user-id",
        "name": "user-name",
        "email": "user@example.com",
        "balance": "0.88",
        "status": "normal",
        "chargeBalance": "88.00",
        "totalBalance": "88.88"
      }
    }
    """

    /// International Region. The same response shape; the account currency is
    /// USD because the international platform bills in USD.
    static let internationalSuccess = """
    {
      "code": 20000,
      "message": "OK",
      "status": true,
      "data": {
        "id": "user-id",
        "name": "user-name",
        "email": "user@example.com",
        "balance": "1.25",
        "status": "normal",
        "chargeBalance": "23.75",
        "totalBalance": "25.00"
      }
    }
    """
}
