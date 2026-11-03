import Foundation

enum KimiCodeFixtures {
    static let domesticSuccess = """
    {
      "usage": {
        "limit": "100",
        "remaining": "74",
        "resetTime": "2026-02-11T17:32:50.757941Z"
      },
      "limits": [
        {
          "window": { "duration": 300, "timeUnit": "TIME_UNIT_MINUTE" },
          "detail": {
            "limit": "100",
            "remaining": "85",
            "resetTime": "2026-02-07T12:32:50.757941Z"
          }
        }
      ],
      "user": { "membership": { "level": "LEVEL_INTERMEDIATE" } }
    }
    """

    static let internationalEnvelope = """
    {
      "data": {
        "usage": {
          "limit": 200,
          "remaining": 40,
          "resetTime": "2026-02-12T08:00:00Z"
        },
        "limits": [
          {
            "window": { "duration": 300, "timeUnit": "TIME_UNIT_MINUTE" },
            "detail": {
              "limit": 200,
              "remaining": 180,
              "resetTime": "2026-02-07T13:00:00Z"
            }
          }
        ]
      }
    }
    """

    static let weeklyMissing = """
    {
      "limits": [
        {
          "window": { "duration": 300, "timeUnit": "TIME_UNIT_MINUTE" },
          "detail": {
            "limit": "100",
            "remaining": "50",
            "resetTime": "2026-02-07T12:32:50.757941Z"
          }
        }
      ]
    }
    """

    static let fiveHourMissing = """
    {
      "usage": {
        "limit": "100",
        "remaining": "74",
        "resetTime": "2026-02-11T17:32:50.757941Z"
      }
    }
    """

    static let zeroLimit = """
    {
      "usage": { "limit": "0", "remaining": "0" },
      "limits": []
    }
    """

    static let invalidWeeklyWithFiveHour = """
    {
      "usage": { "limit": "0", "remaining": "0" },
      "limits": [
        {
          "window": { "duration": 300, "timeUnit": "TIME_UNIT_MINUTE" },
          "detail": { "limit": "100", "remaining": "85" }
        }
      ]
    }
    """

    static let malformedSecondaryWithValidWeekly = """
    {
      "usage": { "limit": "100", "remaining": "74" },
      "limits": [
        {
          "window": { "duration": 300, "timeUnit": "TIME_UNIT_MINUTE" },
          "detail": {
            "limit": "100",
            "remaining": "85",
            "resetTime": "not-a-date"
          }
        }
      ]
    }
    """

    static let fiveHourSeconds = """
    {
      "usage": { "limit": "100", "remaining": "74" },
      "limits": [
        {
          "window": { "duration": 18000, "timeUnit": "TIME_UNIT_SECOND" },
          "detail": { "limit": "100", "remaining": "85" }
        }
      ]
    }
    """

    static let multipleWindows = """
    {
      "usage": { "limit": "100", "remaining": "74" },
      "limits": [
        {
          "window": { "duration": 300, "timeUnit": "TIME_UNIT_MINUTE" },
          "detail": { "limit": "100", "remaining": "85" }
        },
        {
          "window": { "duration": 60, "timeUnit": "TIME_UNIT_MINUTE" },
          "detail": { "limit": "50", "remaining": "25" }
        }
      ]
    }
    """

    /// Newer Kimi Code quota model: weekly/monthly percentage pools alongside
    /// the legacy 5-hour count window.
    static let ratioPools = """
    {
      "limits": [
        {
          "window": { "duration": 300, "timeUnit": "TIME_UNIT_MINUTE" },
          "detail": {
            "limit": "200",
            "used": "0",
            "remaining": "200",
            "resetTime": "2026-02-07T12:32:50.757941Z"
          }
        }
      ],
      "usages": {
        "limit_5h": {
          "used_ratio": 0,
          "reset_time": "2026-02-07T12:32:50.757941Z"
        },
        "limit_7d": {
          "used_ratio": 0.0844,
          "reset_time": "2026-02-11T17:32:50.757941Z"
        },
        "limit_month_total": {
          "used_ratio": 0.2,
          "reset_time": "2026-03-01T00:00:00Z"
        }
      }
    }
    """

    static let ratioPoolsWithoutWeekly = """
    {
      "usages": {
        "limit_5h": { "used_ratio": 0 },
        "limit_month_total": {
          "used_ratio": 8.44,
          "reset_time": "2026-03-01T00:00:00Z"
        }
      }
    }
    """

    static let ratioPoolsEnvelope = """
    {
      "data": {
        "usages": {
          "limit_7d": {
            "used_ratio": "0.0844",
            "reset_time": "2026-02-11T17:32:50.757941Z"
          }
        }
      }
    }
    """

    static let malformed = """
    { "unexpected": true }
    """
}
