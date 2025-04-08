# Configure spark on a hadoop cluster with kerberos

Suppose the Hadoop cluster has the below architecture:

```text
10.50.5.199	    hadoop-client.casdds.casd	# hadoop-client
10.50.5.203	    spark-m01.casdds.casd	# name node
10.50.5.204     spark-m02.casdds.casd   # data node 1
10.50.5.205     spark-m03.casdds.casd  # data node 2
```

Our goal is to install and configure a `spark client` in `hadoop-client`, which can submit spark jobs. 

## 1. Create service principals



### 1.1. Create service account principals

We need to have service account principals in all name nodes and data nodes. We recommend you to follow a clear
naming convention to facilitate the principal and keytab management. Below is a list of general forms for these
service principals

```shell
host/<FQDN>@REALM
hdfs/<FQDN>@REALM
http/<FQDN>@REALM
yarn/<FQDN>@REALM
# 
```


<FQDN> is the fully qualified domain name of the host where Spark runs (can be a wildcard for multi-host setups).

This principal must have a corresponding keytab file to be used during job submission or by services like YARN.




This is usually already set up if your Hadoop cluster is Kerberized.

3. YARN principal
If Spark is run in cluster mode with YARN as the resource manager:


Required for authenticating Spark with the YARN ResourceManager.

4. User principal (for job submission)
The user submitting the Spark job:

<username>@REALM
This is the Kerberos identity of the person or service submitting the job.

It must have a valid TGT (ticket-granting ticket) or keytab.

## Submit spark jobs to hadoop cluster
Spark can take kerberos tickets automatically to the hadoop cluster via yarn.
We don't need to specific configuration. We only need to make sure the user
has obtained a valid TGT ticket.

But if the spark job runs longer than the validity of the ticket, the job will fail. So the best practice
is to use a keytab file which allows spark to ask new tickets if it needs. Below is an example
of the spark-submit commands

```shell
spark-submit --master yarn --deploy-mode cluster \
  --principal hadoop-user@EXAMPLE.COM \
  --keytab /etc/security/keytabs/hadoop-user.keytab \
  --class com.example.MyApp hdfs:///user/hadoop-user/myapp.jar
```

You can also configure the `spark-defaults.conf`:

```shell
spark.yarn.principal hadoop-user@EXAMPLE.COM
spark.yarn.keytab /etc/security/keytabs/hadoop-user.keytab
spark.hadoop.fs.defaultFS hdfs://namenode1.example.com:9000
```


## Test your cluster

### Test 1 : Valid the spark kerberos integration

In test 1, we only do some simple calculation, without accessing hdfs

```python
from pyspark.sql import SparkSession

def main():
    # Create Spark session
    spark = SparkSession.builder \
        .appName("KerberosSparkTest") \
        .getOrCreate()

    # For a basic test, create a small DataFrame
    df = spark.createDataFrame([
        ("Alice", 25),
        ("Bob", 30),
        ("Charlie", 35)
    ], ["name", "age"])

    df.show()

    # Just for validation: print row count
    print(f"Total rows: {df.count()}")

    spark.stop()

if __name__ == "__main__":
    main()

```
```shell
spark-submit \
  --master yarn \
  --deploy-mode cluster \
  --conf spark.hadoop.hadoop.security.authentication=kerberos \
  job1.py
```




```shell
spark-submit \
  --master yarn \
  --deploy-mode cluster \
  --conf spark.hadoop.hadoop.security.authentication=kerberos \
  --conf spark.hadoop.yarn.resourcemanager.address=spark-m01.casdds.casd:8032 \
  --principal pliu@CASDDS.CASD \
  --keytab /home/pliu/pliu-user.keytab \
  job1.py
```


### Test 2 Spark delegate kerberos ticket for Hdfs access control

In test2, we will read a csv file from hdfs, filter users who work for the federal government, then we group workers by sex and 
count the worker number. We will also write the result in hdfs.


```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col

def main():
    # Create Spark session
    spark = SparkSession.builder \
        .appName("census_stats") \
        .getOrCreate()

    # read a file in hdfs
    us_censure_path = "hdfs:///user/pengfei/us_census_1996.csv"
    result_path = "hdfs:///user/pengfei/tmp/census_stats"
    df = spark.read \
        .options(header=True, inferSchema=True, delimiter=',', nullValue="?") \
        .csv(path=us_censure_path)
    df.show(5)
    result = df.filter(col("workclass")=="State-gov").groupby("sex").count()

    # Just for validation: print row count
    print(f"Total rows: {df.count()}")
    result.write.mode("overwrite").options(header=True, delimiter=",").csv(result_path)

    spark.stop()

if __name__ == "__main__":
    main()
```

```shell
spark-submit   --master yarn   --deploy-mode cluster job2.py
```


### Test 3: Test long running spark jobs

In this test, we changed the Ad/Krb ticket policy, the TGT validity is `1 hour`, renewable for `1 day`. The below job
will take about 20 hours to finish. If the job finishes correctly, it means the hadoop cluster can automatically renew
the ticket. 

```shell
from pyspark.sql import SparkSession
import time
def main():
    # Create Spark session
    spark = SparkSession.builder \
        .appName("pengfei_long_running_jobs") \
        .getOrCreate()
    ite_num = 120
    i = 0
    # each iteration sleep for 10 mins
    while i< ite_num:
        # do a basic df count
        df = spark.createDataFrame([
            ("Alice", 25),
            ("Bob", 30),
            ("Charlie", 35)
        ], ["name", "age"])
        df.count()
        # sleep 10 mins
        time.sleep(600)
        i +=1
        print(f"Sleep Iteration: {i}")
    
    spark.stop()

if __name__ == "__main__":
    main()

```