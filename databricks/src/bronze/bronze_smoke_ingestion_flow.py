import sys
from pyspark.sql import SparkSession
from pyspark.sql.functions import current_timestamp, to_date, lit

spark = SparkSession.builder.getOrCreate()

# --- Read parameters from job ---
args = sys.argv

catalog = args[args.index("--catalog") + 1]
schema = args[args.index("--bronze_schema") + 1]

accepted_table = f"{catalog}.{schema}.raw_ingestion_events"
quarantine_table = f"{catalog}.{schema}.raw_ingestion_quarantine"

# --- Simulated ingestion dataset (controlled test input) ---
data = [
    {
        "schema_version": "1.0",
        "source": "api-football",
        "entity_type": "league-status",
        "request_key": "req-1",
        "correlation_id": "corr-1",
        "source_entity_id": "123",

        "league_id": "39",
        "league_name": "Premier League",
        "season": "2024",
        "endpoint": "/leagues",

        "payload_json": '{"status": "active"}',
        "raw_message_json": '{"raw": "message"}',

        "idempotency_key": "abc-123",
        "ingestion_status": "accepted",
        "quarantined": False
    },
    {
        # malformed → quarantine
        "payload_json": None,
        "raw_message_json": '{"bad": "data"}'
    }
]

df = spark.createDataFrame(data)

# --- Split accepted vs quarantine ---
accepted_df = (
    df.filter("payload_json IS NOT NULL")
    .withColumn("ingested_at_utc", current_timestamp())
    .withColumn("event_date", to_date(current_timestamp()))
    .withColumn("kafka_topic", lit("soccer.raw.ingestion.test"))
    .withColumn("kafka_partition", lit(0))
    .withColumn("kafka_offset", lit(0))
)

quarantine_df = (
    df.filter("payload_json IS NULL")
    .withColumn("quarantine_reason", lit("missing payload_json"))
    .withColumn("quarantine_stage", lit("bronze_parse"))
    .withColumn("ingested_at_utc", current_timestamp())
    .withColumn("event_date", to_date(current_timestamp()))
)

# --- Write to Unity Catalog tables ---
accepted_df.write.mode("append").saveAsTable(accepted_table)
quarantine_df.write.mode("append").saveAsTable(quarantine_table)

print("BRONZE INGESTION COMPLETE")