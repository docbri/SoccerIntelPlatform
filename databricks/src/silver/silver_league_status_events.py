import sys

from pyspark.sql import SparkSession
from pyspark.sql import functions as F
from pyspark.sql.window import Window
from pyspark.sql.types import StructField, StructType, StringType, IntegerType


spark = SparkSession.builder.getOrCreate()


def read_arg(args, name):
    if name not in args:
        raise ValueError(f"Missing required argument: {name}")

    index = args.index(name)

    if index + 1 >= len(args):
        raise ValueError(f"Missing value for argument: {name}")

    return args[index + 1]


def payload_schema():
    return StructType(
        [
            StructField("status", StringType(), True),
            StructField("response_length", IntegerType(), True),
            StructField("warning", StringType(), True),
        ]
    )


def main():
    args = sys.argv

    catalog = read_arg(args, "--catalog")
    bronze_schema = read_arg(args, "--bronze_schema")
    silver_schema = read_arg(args, "--silver_schema")

    bronze_table = f"{catalog}.{bronze_schema}.raw_ingestion_events"
    silver_table = f"{catalog}.{silver_schema}.league_status_events"

    print("SILVER TRANSFORMATION STARTED")
    print(f"Bronze table: {bronze_table}")
    print(f"Silver table: {silver_table}")

    bronze_df = spark.table(bronze_table)

    eligible_df = (
        bronze_df
        .filter(F.col("entity_type") == "league-status")
        .filter(F.col("quarantined") == F.lit(False))
        .filter(F.col("ingestion_status") == "accepted")
        .filter(F.col("idempotency_key").isNotNull())
        .filter(F.col("payload_json").isNotNull())
        .filter(F.col("ingested_at_utc").isNotNull())
        .filter(F.col("event_date").isNotNull())
        .filter(F.col("league_id").isNotNull())
        .filter(F.col("season").isNotNull())
    )

    parsed_df = (
        eligible_df
        .withColumn("payload", F.from_json(F.col("payload_json"), payload_schema()))
        .withColumn("api_status", F.col("payload.status"))
        .withColumn("api_response_length", F.col("payload.response_length"))
        .withColumn("api_warning", F.col("payload.warning"))
    )

    window_spec = (
        Window
        .partitionBy("idempotency_key")
        .orderBy(
            F.col("ingested_at_utc").desc(),
            F.col("kafka_offset").desc(),
            F.col("kafka_partition").desc(),
        )
    )

    silver_df = (
        parsed_df
        .withColumn("rn", F.row_number().over(window_spec))
        .filter(F.col("rn") == 1)
        .select(
            F.col("idempotency_key"),
            F.col("schema_version"),
            F.col("source"),
            F.col("entity_type"),
            F.col("request_key"),
            F.col("correlation_id"),
            F.col("source_entity_id"),
            F.col("league_id").cast("int").alias("league_id"),
            F.col("league_name"),
            F.col("season").cast("int").alias("season"),
            F.col("endpoint"),
            F.col("api_status"),
            F.col("api_response_length").cast("int").alias("api_response_length"),
            F.col("api_warning"),
            F.col("fetched_at_utc"),
            F.col("kafka_timestamp_utc"),
            F.col("ingested_at_utc"),
            F.col("event_date"),
            F.col("payload_json"),
            F.col("raw_message_json"),
        )
    )

    output_count = silver_df.count()

    (
        silver_df
        .write
        .mode("overwrite")
        .option("overwriteSchema", "true")
        .partitionBy("event_date")
        .saveAsTable(silver_table)
    )

    print(f"Silver rows written: {output_count}")
    print("SILVER TRANSFORMATION COMPLETE")


if __name__ == "__main__":
    main()
