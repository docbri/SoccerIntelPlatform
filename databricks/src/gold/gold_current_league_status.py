# Gold current league status placeholder
#
# Intended future behavior:
# - Read silver.league_status_events
# - Select the latest event per league and season
# - Derive status_category
# - Write to gold.current_league_status


def describe_gold_current_league_status_flow():
    return {
        "source_table": "silver.league_status_events",
        "target_table": "gold.current_league_status",
        "grain": "one row per league_id, league_name, season",
        "rules": [
            "Select latest row by ingested_at_utc",
            "Preserve lineage fields",
            "Derive status_category from api_warning and api_status"
        ]
    }


if __name__ == "__main__":
    print(describe_gold_current_league_status_flow())

