import sys

from pyspark.sql import SparkSession
from pyspark.sql import functions as F
from pyspark.sql.types import (
    StructField,
    StructType,
    StringType,
    IntegerType,
    TimestampType,
)


spark = SparkSession.builder.getOrCreate()


def read_arg(args, name, default=None):
    if name not in args:
        if default is not None:
            return default
        raise ValueError(f"Missing required argument: {name}")

    index = args.index(name)
    if index + 1 >= len(args):
        raise ValueError(f"Missing value for argument: {name}")

    return args[index + 1]


def ingestion_envelope_schema():
    return StructType(
        [
            StructField("SchemaVersion", StringType(), True),
            StructField("Source", StringType(), True),
            StructField("EntityType", StringType(), True),
            StructField("LeagueId", IntegerType(), True),
            StructField("LeagueName", StringType(), True),
            StructField("Season", IntegerType(), True),
            StructField("CorrelationId", StringType(), True),
            StructField("FetchedAtUtc", TimestampType(), True),
            StructField("Endpoint", StringType(), True),
            StructField("RequestKey", StringType(), True),
            StructField("SourceEntityId", StringType(), True),
            StructField("PayloadJson", StringType(), True),
        ]
    )


def with_transport_columns(kafka_df):
    return kafka_df.select(
        F.col("topic").alias("kafka_topic"),
        F.col("partition").alias("kafka_partition"),
        F.col("offset").alias("kafka_offset"),
        F.col("timestamp").alias("kafka_timestamp_utc"),
        F.col("value").cast("string").alias("raw_message_json"),
    )


def parse_outer_envelope(df):
    return df.withColumn(
        "envelope",
        F.from_json(F.col("raw_message_json"), ingestion_envelope_schema()),
    )


def with_derived_columns(df):
    return (
        df.withColumn("ingested_at_utc", F.current_timestamp())
        .withColumn("event_date", F.to_date(F.col("ingested_at_utc")))
        .withColumn(
            "idempotency_key",
            F.concat_ws(
                "|",
                F.col("kafka_topic"),
                F.col("kafka_partition").cast("string"),
                F.col("kafka_offset").cast("string"),
            ),
        )
    )


def with_validation_reason(df):
    null_envelope_reason = F.when(
        F.col("envelope").isNull(),
        F.lit("Envelope parse failure"),
    )

    semantic_reason = F.when(
        F.col("envelope").isNotNull(),
        F.when(
            F.col("envelope.SchemaVersion").isNull()
            | (F.trim(F.col("envelope.SchemaVersion")) == ""),
            F.lit("SchemaVersion is required"),
            )
        .when(
            F.col("envelope.Source").isNull()
            | (F.trim(F.col("envelope.Source")) == ""),
            F.lit("Source is required"),
            )
        .when(
            F.col("envelope.EntityType").isNull()
            | (F.trim(F.col("envelope.EntityType")) == ""),
            F.lit("EntityType is required"),
            )
        .when(
            F.col("envelope.LeagueId").isNull() | (F.col("envelope.LeagueId") <= 0),
            F.lit("LeagueId must be greater than zero"),
            )
        .when(
            F.col("envelope.Season").isNull() | (F.col("envelope.Season") <= 0),
            F.lit("Season must be greater than zero"),
            )
        .when(
            F.col("envelope.CorrelationId").isNull()
            | (F.trim(F.col("envelope.CorrelationId")) == ""),
            F.lit("CorrelationId is required"),
            )
        .when(
            F.col("envelope.Endpoint").isNull()
            | (F.trim(F.col("envelope.Endpoint")) == ""),
            F.lit("Endpoint is required"),
            )
        .when(
            F.col("envelope.RequestKey").isNull()
            | (F.trim(F.col("envelope.RequestKey")) == ""),
            F.lit("RequestKey is required"),
            )
        .when(
            F.col("envelope.SourceEntityId").isNull()
            | (F.trim(F.col("envelope.SourceEntityId")) == ""),
            F.lit("SourceEntityId is required"),
            )
        .when(
            F.col("envelope.PayloadJson").isNull()
            | (F.trim(F.col("envelope.PayloadJson")) == ""),
            F.lit("PayloadJson is required"),
            ),
        )

    return df.withColumn(
        "validation_reason",
        F.coalesce(null_envelope_reason, semantic_reason),
    )


def accepted_records(df):
    return (
        df.filter(F.col("validation_reason").isNull())
        .select(
            F.col("envelope.SchemaVersion").alias("schema_version"),
            F.col("envelope.Source").alias("source"),
            F.col("envelope.EntityType").alias("entity_type"),
            F.col("envelope.RequestKey").alias("request_key"),
            F.col("envelope.CorrelationId").alias("correlation_id"),
            F.col("envelope.SourceEntityId").alias("source_entity_id"),
            F.col("envelope.LeagueId").cast("string").alias("league_id"),
            F.col("envelope.LeagueName").alias("league_name"),
            F.col("envelope.Season").cast("string").alias("season"),
            F.col("envelope.Endpoint").alias("endpoint"),
            F.col("envelope.FetchedAtUtc").alias("fetched_at_utc"),
            F.col("kafka_timestamp_utc"),
            F.col("ingested_at_utc"),
            F.col("event_date"),
            F.col("kafka_topic"),
            F.col("kafka_partition"),
            F.col("kafka_offset"),
            F.col("envelope.PayloadJson").alias("payload_json"),
            F.col("raw_message_json"),
            F.col("idempotency_key"),
            F.lit("accepted").alias("ingestion_status"),
            F.lit(False).alias("quarantined"),
        )
    )


def quarantine_records(df):
    return (
        df.filter(F.col("validation_reason").isNotNull())
        .select(
            F.col("validation_reason").alias("reason"),
            F.array(F.col("validation_reason")).alias("validation_errors"),
            F.col("kafka_topic"),
            F.col("kafka_partition"),
            F.col("kafka_offset"),
            F.col("kafka_timestamp_utc"),
            F.col("ingested_at_utc").alias("quarantined_at_utc"),
            F.col("event_date"),
            F.col("raw_message_json"),
        )
    )


def remove_existing_offsets(df, table_name):
    if not spark.catalog.tableExists(table_name):
        return df

    existing_table = spark.table(table_name)
    required_columns = {"kafka_topic", "kafka_partition", "kafka_offset"}
    existing_columns = set(existing_table.columns)

    if not required_columns.issubset(existing_columns):
        print(
            f"Skipping offset de-duplication for {table_name}; "
            f"existing table does not contain Kafka metadata columns. "
            f"Existing columns: {sorted(existing_columns)}"
        )
        return df

    existing_offsets = (
        existing_table
        .select("kafka_topic", "kafka_partition", "kafka_offset")
        .dropDuplicates()
    )

    return df.join(
        existing_offsets,
        on=["kafka_topic", "kafka_partition", "kafka_offset"],
        how="left_anti",
    )

def main():
    args = sys.argv

    catalog = read_arg(args, "--catalog")
    bronze_schema = read_arg(args, "--bronze_schema")
    kafka_bootstrap_servers = read_arg(args, "--kafka_bootstrap_servers")
    topic_name = read_arg(args, "--topic_name", "soccer.raw.ingestion.dev")
    starting_offsets = read_arg(args, "--starting_offsets", "earliest")
    ending_offsets = read_arg(args, "--ending_offsets", "latest")

    accepted_table = f"{catalog}.{bronze_schema}.raw_ingestion_events"
    quarantine_table = f"{catalog}.{bronze_schema}.raw_ingestion_quarantine"

    print("BRONZE KAFKA INGESTION STARTED")
    print(f"Catalog: {catalog}")
    print(f"Bronze schema: {bronze_schema}")
    print(f"Kafka bootstrap servers: {kafka_bootstrap_servers}")
    print(f"Topic name: {topic_name}")
    print(f"Accepted table: {accepted_table}")
    print(f"Quarantine table: {quarantine_table}")
    print(f"Starting offsets: {starting_offsets}")
    print(f"Ending offsets: {ending_offsets}")

    kafka_df = (
        spark.read.format("kafka")
        .option("kafka.bootstrap.servers", kafka_bootstrap_servers)
        .option("subscribe", topic_name)
        .option("startingOffsets", starting_offsets)
        .option("endingOffsets", ending_offsets)
        .load()
    )

    transport_df = with_transport_columns(kafka_df)
    parsed_df = parse_outer_envelope(transport_df)
    enriched_df = with_derived_columns(parsed_df)
    validated_df = with_validation_reason(enriched_df)

    accepted_df = remove_existing_offsets(
        accepted_records(validated_df),
        accepted_table,
    )

    quarantine_df = remove_existing_offsets(
        quarantine_records(validated_df),
        quarantine_table,
    )

    accepted_count = accepted_df.count()
    quarantine_count = quarantine_df.count()

    if accepted_count > 0:
        accepted_df.write.mode("append").saveAsTable(accepted_table)

    if quarantine_count > 0:
        quarantine_df.write.mode("append").saveAsTable(quarantine_table)

    print(f"Accepted rows written: {accepted_count}")
    print(f"Quarantine rows written: {quarantine_count}")
    print("BRONZE INGESTION COMPLETE")


if __name__ == "__main__":
    main()
