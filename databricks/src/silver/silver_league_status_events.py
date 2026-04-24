from pyspark.sql import SparkSession

spark = SparkSession.builder.getOrCreate()

spark.range(1).count()

print("SILVER EXECUTION WORKED")
