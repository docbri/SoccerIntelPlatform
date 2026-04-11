CREATE TABLE IF NOT EXISTS bronze.raw_ingestion_quarantine (
    reason STRING,
    validation_errors ARRAY<STRING>,
    kafka_topic STRING,
    kafka_partition INT,
    kafka_offset BIGINT,
    kafka_timestamp_utc TIMESTAMP,
    quarantined_at_utc TIMESTAMP,
    event_date DATE,
    raw_message_json STRING
)
USING DELTA
PARTITIONED BY (event_date);

