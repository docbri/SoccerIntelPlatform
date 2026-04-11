CREATE TABLE IF NOT EXISTS silver.league_status_events (
    idempotency_key STRING,
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
    api_status STRING,
    api_response_length INT,
    api_warning STRING,
    fetched_at_utc TIMESTAMP,
    kafka_timestamp_utc TIMESTAMP,
    ingested_at_utc TIMESTAMP,
    event_date DATE,
    payload_json STRING,
    raw_message_json STRING
)
USING DELTA
PARTITIONED BY (event_date);

