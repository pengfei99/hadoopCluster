# Configure spark on a hadoop cluster with kerberos


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
