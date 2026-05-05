import os
import sys
from typing import Optional

from pyspark.sql import SparkSession


spark = SparkSession.builder.getOrCreate()


def read_arg(args, name, required=True, default=None):
    if name not in args:
        if required:
            raise ValueError(f"Missing required argument: {name}")
        return default

    index = args.index(name)

    if index + 1 >= len(args):
        raise ValueError(f"Missing value for argument: {name}")

    return args[index + 1]


def read_secret(scope: str, key: str) -> Optional[str]:
    try:
        from pyspark.dbutils import DBUtils

        dbutils = DBUtils(spark)
        value = dbutils.secrets.get(scope=scope, key=key)
        return value if value else None
    except Exception:
        return None


def read_config_value(
    *,
    env_name: str,
    secret_scope: Optional[str],
    secret_key: Optional[str],
    required: bool = True,
) -> Optional[str]:
    env_value = os.getenv(env_name)

    if env_value:
        return env_value

    if secret_scope and secret_key:
        secret_value = read_secret(secret_scope, secret_key)

        if secret_value:
            return secret_value

    if required:
        raise ValueError(
            f"Missing Snowflake configuration value. "
            f"Set environment variable {env_name}"
            + (
                f" or Databricks secret {secret_scope}/{secret_key}."
                if secret_scope and secret_key
                else "."
            )
        )

    return None


def build_snowflake_options(args):
    sf_url = read_config_value(
        env_name="SNOWFLAKE_URL",
        secret_scope=secret_scope,
        secret_key="url",
    )

    sf_user = read_config_value(
        env_name="SNOWFLAKE_USER",
        secret_scope=secret_scope,
        secret_key="user",
    )

    sf_password = read_config_value(
        env_name="SNOWFLAKE_PASSWORD",
        secret_scope=secret_scope,
        secret_key="password",
    )

    sf_role = read_config_value(
        env_name="SNOWFLAKE_ROLE",
        secret_scope=secret_scope,
        secret_key="role",
    )

    sf_warehouse = read_config_value(
        env_name="SNOWFLAKE_WAREHOUSE",
        secret_scope=secret_scope,
        secret_key="warehouse",
    )

    return {
        "sfURL": sf_url,
        "sfUser": sf_user,
        "sfPassword": sf_password,
        "sfRole": sf_role,
        "sfWarehouse": sf_warehouse,
    }


def main():
    args = sys.argv

    catalog = read_arg(args, "--catalog")
    gold_schema = read_arg(args, "--gold_schema")
    snowflake_database = read_arg(args, "--snowflake_database")
    snowflake_schema = read_arg(args, "--snowflake_schema")
    snowflake_table = read_arg(args, "--snowflake_table")
    source_table = f"{catalog}.{gold_schema}.current_league_status"
    target_table = f"{snowflake_database}.{snowflake_schema}.{snowflake_table}"

    print("SNOWFLAKE PUBLISH STARTED")
    print(f"Source table: {source_table}")
    print(f"Target table: {target_table}")
    print("Write mode: overwrite")

    source_df = spark.table(source_table)
    source_count = source_df.count()

    print(f"Source rows: {source_count}")

    snowflake_options = build_snowflake_options(args)

    snowflake_options["sfDatabase"] = snowflake_database
    snowflake_options["sfSchema"] = snowflake_schema

    (
        source_df
        .write
        .format("snowflake")
        .options(**snowflake_options)
        .option("dbtable", snowflake_table)
        .mode("overwrite")
        .save()
    )

    print(f"Snowflake rows written: {source_count}")
    print("SNOWFLAKE PUBLISH COMPLETE")


if __name__ == "__main__":
    main()
