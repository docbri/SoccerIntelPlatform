CREATE TABLE IF NOT EXISTS gold.current_league_status (
    league_id INT,
    league_name STRING,
    season INT,
    api_status STRING,
    api_response_length INT,
    api_warning STRING,
    status_category STRING,
    latest_idempotency_key STRING,
    latest_request_key STRING,
    latest_correlation_id STRING,
    latest_fetched_at_utc TIMESTAMP,
    latest_ingested_at_utc TIMESTAMP,
    event_date DATE,
    latest_payload_json STRING
)
USING DELTA
PARTITIONED BY (event_date);

