# Spark submit parameters

## 

```shell
spark-submit --master yarn --deploy-mode cluster --conf spark.yarn.queue=prod --conf spark.yarn.archive=hdfs:///system/libs/spark_libs.zip
 --conf spark.pyspark.driver.python=/usr/bin/python3 --conf spark.pyspark.python=/usr/bin/python3 --conf spark.yarn.am.memory=4g
```