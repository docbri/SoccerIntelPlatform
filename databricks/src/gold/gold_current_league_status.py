import sys
from pyspark.sql import SparkSession
from pyspark.sql.window import Window
from pyspark.sql.functions import col, row_number

spark = SparkSession.builder.getOrCreate()

# --- Params ---
args = sys.argv

catalog = args[args.index("--catalog") + 1]
silver_schema = args[args.index("--silver_schema") + 1]
gold_schema = args[args.index("--gold_schema") + 1]

silver_table = f"{catalog}.{silver_schema}.league_status_events"
gold_table = f"{catalog}.{gold_schema}.current_league_status"

# --- Read Silver ---
df = spark.table(silver_table)

# --- Window for latest record per league/season ---
window_spec = Window.partitionBy("league_id", "season") \
    .orderBy(col("processed_at_utc").desc())

# --- Transform ---
gold_df = (
    df
    .withColumn("rn", row_number().over(window_spec))
    .filter(col("rn") == 1)
    .drop("rn")
)

# --- Write (overwrite to keep only current state) ---
gold_df.write.mode("overwrite").saveAsTable(gold_table)

print("GOLD TRANSFORMATION COMPLETE")
