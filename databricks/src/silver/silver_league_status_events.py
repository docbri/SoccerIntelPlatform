import sys
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, from_json, current_timestamp
from pyspark.sql.types import StructType, StructField, StringType

spark = SparkSession.builder.getOrCreate()

# --- Params ---
args = sys.argv

catalog = args[args.index("--catalog") + 1]
bronze_schema = args[args.index("--bronze_schema") + 1]
silver_schema = args[args.index("--silver_schema") + 1]

bronze_table = f"{catalog}.{bronze_schema}.raw_ingestion_events"
silver_table = f"{catalog}.{silver_schema}.league_status_events"

# --- Define payload schema ---
payload_schema = StructType([
    StructField("status", StringType(), True)
])

# --- Read Bronze ---
df = spark.table(bronze_table)

# --- Transform ---
silver_df = (
    df
    # Only valid rows
    .filter(col("payload_json").isNotNull())

    # Parse payload JSON
    .withColumn("payload", from_json(col("payload_json"), payload_schema))
    .withColumn("status", col("payload.status"))

    # Deduplicate
    .dropDuplicates(["idempotency_key"])

    # Add processing timestamp
    .withColumn("processed_at_utc", current_timestamp())

    # Select final columns
    .select(
        "league_id",
        "league_name",
        "season",
        "status",
        "idempotency_key",
        "processed_at_utc"
    )
)

# --- Write ---
silver_df.write.mode("append").saveAsTable(silver_table)

print("SILVER TRANSFORMATION COMPLETE")
