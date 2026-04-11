# Snowflake Spark Connector placeholder
#
# Intended future behavior:
# 1. Read the curated Gold table from Databricks
# 2. Configure Snowflake connector options
# 3. Write to SOCCER_INTEL.CURATED.CURRENT_LEAGUE_STATUS
# 4. Use overwrite semantics for the first version


SNOWFLAKE_OPTIONS = {
    "sfURL": "<account_identifier>.snowflakecomputing.com",
    "sfUser": "<user>",
    "sfPassword": "<password-or-token>",
    "sfDatabase": "SOCCER_INTEL",
    "sfSchema": "CURATED",
    "sfWarehouse": "<warehouse>",
}

SOURCE_TABLE = "gold.current_league_status"
TARGET_TABLE = "CURRENT_LEAGUE_STATUS"


def publish_current_league_status_to_snowflake(spark):
    df = spark.table(SOURCE_TABLE)

    (
        df.write
        .format("snowflake")
        .options(**SNOWFLAKE_OPTIONS)
        .option("dbtable", TARGET_TABLE)
        .mode("overwrite")
        .save()
    )

