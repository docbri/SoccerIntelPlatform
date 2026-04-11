CREATE TABLE IF NOT EXISTS bronze.raw_ingestion_events (
    schema_version STRING,
    source STRING,
    entity_type STRING,
    request_key STRING,
    correlation_id STRING,
    source_entity_id STRING,
    league_id INT,
    league_name STRING,
    season INT,
    endpoint STRING,
    fetched_at_utc TIMESTAMP,
    kafka_timestamp_utc TIMESTAMP,
    ingested_at_utc TIMESTAMP,
    event_date DATE,
    kafka_topic STRING,
    kafka_partition INT,
    kafka_offset BIGINT,
    payload_json STRING,
    raw_message_json STRING,
    idempotency_key STRING,
    ingestion_status STRING,
    quarantined BOOLEAN
)
USING DELTA
PARTITIONED BY (event_date);

