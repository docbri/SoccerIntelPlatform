# Bronze ingestion placeholder
#
# Intended responsibility:
# Read Kafka topic messages containing IngestionEnvelope JSON
# and persist them into the Bronze table:
#
# bronze.raw_ingestion_events
#
# This file is a design placeholder for the first Databricks Bronze job.


def describe_bronze_ingestion():
    return {
        "source": "kafka",
        "topic_pattern": "soccer.raw.ingestion*",
        "target_table": "bronze.raw_ingestion_events",
        "mode": "append",
        "notes": [
            "Read Kafka value as JSON string",
            "Parse outer IngestionEnvelope fields",
            "Preserve payload_json as raw text",
            "Persist Kafka metadata columns",
            "Do not normalize domain semantics here"
        ]
    }


if __name__ == "__main__":
    print(describe_bronze_ingestion())
