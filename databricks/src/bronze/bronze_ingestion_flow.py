# Bronze ingestion flow placeholder
#
# Intended future behavior:
# 1. Read Kafka topic(s) containing JSON serialized IngestionEnvelope records
# 2. Preserve Kafka metadata
# 3. Parse outer envelope fields
# 4. Add ingestion metadata
# 5. Append valid rows to bronze.raw_ingestion_events
# 6. Append malformed or invalid rows to bronze.raw_ingestion_quarantine


def describe_bronze_ingestion_flow():
    return {
        "source": "kafka",
        "topic_pattern": "soccer.raw.ingestion*",
        "valid_target_table": "bronze.raw_ingestion_events",
        "quarantine_target_table": "bronze.raw_ingestion_quarantine",
        "mode": "streaming append",
        "rules": [
            "Preserve kafka metadata",
            "Preserve raw message json",
            "Preserve payload_json as text",
            "Append valid rows to Bronze",
            "Append invalid rows to quarantine",
            "Do not normalize football semantics in Bronze"
        ]
    }


if __name__ == "__main__":
    print(describe_bronze_ingestion_flow())

