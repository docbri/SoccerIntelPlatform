import sys

from pyspark.sql import SparkSession
from pyspark.sql import functions as F
from pyspark.sql.window import Window


spark = SparkSession.builder.getOrCreate()


def read_arg(args, name):
    if name not in args:
        raise ValueError(f"Missing required argument: {name}")

    index = args.index(name)

    if index + 1 >= len(args):
        raise ValueError(f"Missing value for argument: {name}")

    return args[index + 1]


def main():
    args = sys.argv

    catalog = read_arg(args, "--catalog")
    silver_schema = read_arg(args, "--silver_schema")
    gold_schema = read_arg(args, "--gold_schema")

    silver_table = f"{catalog}.{silver_schema}.league_status_events"
    gold_table = f"{catalog}.{gold_schema}.current_league_status"

    print("GOLD TRANSFORMATION STARTED")
    print(f"Silver table: {silver_table}")
    print(f"Gold table: {gold_table}")

    silver_df = spark.table(silver_table)

    window_spec = (
        Window
        .partitionBy("league_id", "league_name", "season")
        .orderBy(
            F.col("ingested_at_utc").desc(),
            F.col("fetched_at_utc").desc(),
            F.col("idempotency_key").desc(),
        )
    )

    latest_df = (
        silver_df
        .withColumn("rn", F.row_number().over(window_spec))
        .filter(F.col("rn") == 1)
    )

    gold_df = (
        latest_df
        .withColumn(
            "status_category",
            F.when(
                F.col("api_warning").isNotNull() & (F.trim(F.col("api_warning")) != ""),
                F.lit("warning"),
                )
            .when(
                F.col("api_status").isNotNull() & (F.trim(F.col("api_status")) != ""),
                F.lit("ok"),
                )
            .otherwise(F.lit("unknown")),
            )
        .select(
            F.col("league_id").cast("int").alias("league_id"),
            F.col("league_name"),
            F.col("season").cast("int").alias("season"),
            F.col("api_status"),
            F.col("api_response_length").cast("int").alias("api_response_length"),
            F.col("api_warning"),
            F.col("status_category"),
            F.col("idempotency_key").alias("latest_idempotency_key"),
            F.col("request_key").alias("latest_request_key"),
            F.col("correlation_id").alias("latest_correlation_id"),
            F.col("fetched_at_utc").alias("latest_fetched_at_utc"),
            F.col("ingested_at_utc").alias("latest_ingested_at_utc"),
            F.col("event_date"),
            F.col("payload_json").alias("latest_payload_json"),
        )
    )

    output_count = gold_df.count()

    (
        gold_df
        .write
        .mode("overwrite")
        .option("overwriteSchema", "true")
        .partitionBy("event_date")
        .saveAsTable(gold_table)
    )

    print(f"Gold rows written: {output_count}")
    print("GOLD TRANSFORMATION COMPLETE")


if __name__ == "__main__":
    main()
