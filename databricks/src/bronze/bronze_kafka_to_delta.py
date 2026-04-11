from pyspark.sql import functions as F
from pyspark.sql.types import (
    StructType,
    StructField,
    StringType,
    IntegerType,
    TimestampType,
    ArrayType,
    BooleanType,
)

# -----------------------------------------------------------------------------
# Bronze Kafka -> Delta ingestion design placeholder
#
# Purpose:
# - Read Kafka messages containing JSON-serialized IngestionEnvelope values
# - Parse outer envelope fields
# - Preserve raw message and payload_json
# - Route valid records to bronze.raw_ingestion_events
# - Route invalid records to bronze.raw_ingestion_quarantine
# -----------------------------------------------------------------------------

KAFKA_BOOTSTRAP_SERVERS = "localhost:9092"
TOPIC_PATTERN = "soccer.raw.ingestion.*"

VALID_CHECKPOINT = "/tmp/checkpoints/bronze/raw_ingestion_events"
QUARANTINE_CHECKPOINT = "/tmp/checkpoints/bronze/raw_ingestion_quarantine"

VALID_TABLE = "bronze.raw_ingestion_events"
QUARANTINE_TABLE = "bronze.raw_ingestion_quarantine"


def ingestion_envelope_schema():
    return StructType([
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
    ])


def read_kafka_stream(spark):
    return (
        spark.readStream
        .format("kafka")
        .option("kafka.bootstrap.servers", KAFKA_BOOTSTRAP_SERVERS)
        .option("subscribePattern", TOPIC_PATTERN)
        .option("startingOffsets", "latest")
        .load()
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
        F.from_json(F.col("raw_message_json"), ingestion_envelope_schema())
    )


def with_derived_columns(df):
    return (
        df.withColumn("ingested_at_utc", F.current_timestamp())
          .withColumn("event_date", F.to_date(F.col("ingested_at_utc")))
          .withColumn(
              "idempotency_key",
              F.concat_ws(
                  "|",
                  F.col("envelope.Source"),
                  F.col("envelope.EntityType"),
                  F.col("envelope.RequestKey"),
              )
          )
    )


def valid_records(df):
    return (
        df.filter(F.col("envelope").isNotNull())
          .filter(F.col("envelope.SchemaVersion").isNotNull() & (F.trim(F.col("envelope.SchemaVersion")) != ""))
          .filter(F.col("envelope.Source").isNotNull() & (F.trim(F.col("envelope.Source")) != ""))
          .filter(F.col("envelope.EntityType").isNotNull() & (F.trim(F.col("envelope.EntityType")) != ""))
          .filter(F.col("envelope.LeagueId") > 0)
          .filter(F.col("envelope.Season") > 0)
          .filter(F.col("envelope.CorrelationId").isNotNull() & (F.trim(F.col("envelope.CorrelationId")) != ""))
          .filter(F.col("envelope.Endpoint").isNotNull() & (F.trim(F.col("envelope.Endpoint")) != ""))
          .filter(F.col("envelope.RequestKey").isNotNull() & (F.trim(F.col("envelope.RequestKey")) != ""))
          .filter(F.col("envelope.SourceEntityId").isNotNull() & (F.trim(F.col("envelope.SourceEntityId")) != ""))
          .filter(F.col("envelope.PayloadJson").isNotNull() & (F.trim(F.col("envelope.PayloadJson")) != ""))
          .select(
              F.col("envelope.SchemaVersion").alias("schema_version"),
              F.col("envelope.Source").alias("source"),
              F.col("envelope.EntityType").alias("entity_type"),
              F.col("envelope.RequestKey").alias("request_key"),
              F.col("envelope.CorrelationId").alias("correlation_id"),
              F.col("envelope.SourceEntityId").alias("source_entity_id"),
              F.col("envelope.LeagueId").alias("league_id"),
              F.col("envelope.LeagueName").alias("league_name"),
              F.col("envelope.Season").alias("season"),
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
    null_envelope_reason = F.when(
        F.col("envelope").isNull(),
        F.lit("Envelope parse failure")
    )

    semantic_reason = F.when(
        F.col("envelope").isNotNull(),
        F.when(F.col("envelope.SchemaVersion").isNull() | (F.trim(F.col("envelope.SchemaVersion")) == ""), F.lit("SchemaVersion is required"))
         .when(F.col("envelope.Source").isNull() | (F.trim(F.col("envelope.Source")) == ""), F.lit("Source is required"))
         .when(F.col("envelope.EntityType").isNull() | (F.trim(F.col("envelope.EntityType")) == ""), F.lit("EntityType is required"))
         .when(F.col("envelope.LeagueId") <= 0, F.lit("LeagueId must be greater than zero"))
         .when(F.col("envelope.Season") <= 0, F.lit("Season must be greater than zero"))
         .when(F.col("envelope.CorrelationId").isNull() | (F.trim(F.col("envelope.CorrelationId")) == ""), F.lit("CorrelationId is required"))
         .when(F.col("envelope.Endpoint").isNull() | (F.trim(F.col("envelope.Endpoint")) == ""), F.lit("Endpoint is required"))
         .when(F.col("envelope.RequestKey").isNull() | (F.trim(F.col("envelope.RequestKey")) == ""), F.lit("RequestKey is required"))
         .when(F.col("envelope.SourceEntityId").isNull() | (F.trim(F.col("envelope.SourceEntityId")) == ""), F.lit("SourceEntityId is required"))
         .when(F.col("envelope.PayloadJson").isNull() | (F.trim(F.col("envelope.PayloadJson")) == ""), F.lit("PayloadJson is required"))
    )

    return (
        df.withColumn("reason", F.coalesce(null_envelope_reason, semantic_reason))
          .filter(F.col("reason").isNotNull())
          .withColumn("event_date", F.to_date(F.col("ingested_at_utc")))
          .select(
              F.col("reason"),
              F.array(F.col("reason")).alias("validation_errors"),
              F.col("kafka_topic"),
              F.col("kafka_partition"),
              F.col("kafka_offset"),
              F.col("kafka_timestamp_utc"),
              F.col("ingested_at_utc").alias("quarantined_at_utc"),
              F.col("event_date"),
              F.col("raw_message_json"),
          )
    )


def write_valid_stream(df):
    return (
        df.writeStream
        .format("delta")
        .outputMode("append")
        .option("checkpointLocation", VALID_CHECKPOINT)
        .toTable(VALID_TABLE)
    )


def write_quarantine_stream(df):
    return (
        df.writeStream
        .format("delta")
        .outputMode("append")
        .option("checkpointLocation", QUARANTINE_CHECKPOINT)
        .toTable(QUARANTINE_TABLE)
    )


def build_streams(spark):
    kafka_df = read_kafka_stream(spark)
    transport_df = with_transport_columns(kafka_df)
    parsed_df = parse_outer_envelope(transport_df)
    enriched_df = with_derived_columns(parsed_df)

    valid_df = valid_records(enriched_df)
    quarantine_df = quarantine_records(enriched_df)

    valid_query = write_valid_stream(valid_df)
    quarantine_query = write_quarantine_stream(quarantine_df)

    return valid_query, quarantine_query

