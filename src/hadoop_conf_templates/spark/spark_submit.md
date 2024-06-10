# Spark submit parameters

In this tutorial, we will show different spark submit commands with various options. All spark script for spark submit,
don't the following in the sparkSession creation. It will take no effect
- reserve the `cpu and memory for driver, executor` 
- include the dependencies jar
- etc.

Below is an example of the spark session creation

```python

```

## Submit python script

### Various master URLs

Spark support various master, the supported `master url` can be in one of the following formats:
- `local` :	Run Spark locally with one worker thread (i.e. no parallelism at all).
- `local[K]`: Run Spark locally with K worker threads (ideally, set this to the number of cores on your machine).
- `local[K,F]`:	Run Spark locally with K worker threads and F maxFailures (see `spark.task.maxFailures` for an explanation of this variable).
- `local[*]`: Run Spark locally with as many worker threads as logical cores on your machine.
- `local[*,F]`:	Run Spark locally with as many worker threads as logical cores on your machine and F maxFailures.
- `local-cluster[N,C,M]`: Local-cluster mode is only for unit tests. It emulates a distributed cluster in a single 
                JVM with N number of workers, C cores per worker and M MiB of memory per worker.
- `spark://HOST:PORT`:	Connect to the given `Spark standalone cluster master`. The port must be whichever one your 
                master is configured to use, which is 7077 by default.
- `spark://HOST1:PORT1,HOST2:PORT2`: Connect to the given `Spark standalone cluster with standby masters with Zookeeper`. 
                The list must have all the master hosts in the high availability cluster set up with Zookeeper. 
                 The port must be whichever each master is configured to use, which is 7077 by default.
- `yarn`: Connect to a YARN cluster in client or cluster mode depending on the value of `--deploy-mode`. The cluster 
             location will be found based on the `HADOOP_CONF_DIR` or `YARN_CONF_DIR` variable.
- `k8s://HOST:PORT`: Connect to a Kubernetes cluster in client or cluster mode depending on the value of 
                  `--deploy-mode`. The HOST and PORT refer to the Kubernetes API Server. It connects using 
                   TLS by default. In order to force it to use an unsecured connection, you can use k8s://http://HOST:PORT.
- `mesos://HOST:PORT(no one use it anymore)`: Connect to the given Mesos cluster. 

> The `spark.task.maxFailures` defines the max number of continuous failures of any particular task before giving 
> up on the job. The default value is 4.

### Command examples

Below are some spark submit command example

#### Local mode

Local mode is quite simple, as all `driver, worker` are only simulated threads, so no need to configure cpu, memory, and
extra dependencies, custom log config in the submit command.

```shell
# Run application locally on 8 cores
./bin/spark-submit \
  --master local[8] \
  /path/to/examples/src/main/python/pi.py \
  1000
```

#### Spark standalone cluster
You can find the official doc [here](https://spark.apache.org/docs/latest/spark-standalone.html)

```shell
# Run on a Spark standalone cluster in client deploy mode
./bin/spark-submit \
  --master spark://207.184.161.138:7077 \
  /path/to/examples/src/main/python/pi.py \
  1000

# Run on a Spark standalone cluster in cluster deploy mode with supervise
./bin/spark-submit \
  --master spark://207.184.161.138:7077 \
  --deploy-mode cluster \
  --supervise \
  /path/to/examples/src/main/python/pi.py \
  1000
```
> In spark standalone cluster mode, you can use the `--supervise` flag, to restart your application automatically if 
> it exited with non-zero exit code.

#### Hadoop Yarn cluster

Yarn supports two deploy-mode:
- `client` : in client mode, the driver runs on the computer which submits the job. An `Application Master(AM)` will be created
            to control the workers. If your job is complexe, you may need to increase the resource of the `AM`
- `cluster` : in cluster mode, the driver runs on a worker of the cluster. The `driver` will play the role of `AM`, 
             so no need to set up resource for `AM`


```shell
# Run on a YARN cluster in client deploy mode
export HADOOP_CONF_DIR=XXX
./bin/spark-submit \
  --class org.apache.spark.examples.SparkPi \
  --master yarn \
  --deploy-mode client \
  --conf spark.yarn.am.memory=4g
  /path/to/examples.jar \
  1000
  
  
# Run on a YARN cluster in cluster deploy mode
export HADOOP_CONF_DIR=XXX
./bin/spark-submit \
  --class org.apache.spark.examples.SparkPi \
  --master yarn \
  --deploy-mode cluster \
  /path/to/examples.jar \
  1000

```
#### K8s cluster

```shell

# Run on a Kubernetes cluster in cluster deploy mode
./bin/spark-submit \
  --master k8s://xx.yy.zz.ww:443 \
  --deploy-mode cluster \
  --executor-memory 20G \
  --num-executors 50 \
  http://path/to/examples.jar \
  1000
```
### Cluster resource options

When running in cluster mode, you need to set up cluster resources:
- --driver-memory 4g \
  --driver-cores 2 \
  --executor-memory 8g \
  --executor-cores 4 \
  --num-executors 10 \

For the script

```shell
spark-submit \
  --master yarn \
  --deploy-mode cluster \
  --driver-memory 4g \
  --driver-cores 2 \
  --executor-memory 8g \
  --executor-cores 4 \
  --num-executors 10 \
  --conf spark.some.config.option=value \

```
### Can't find 

```shell
spark-submit --master yarn --deploy-mode cluster --conf spark.yarn.queue=prod --conf spark.yarn.archive=hdfs:///system/libs/spark_libs.zip
 --conf spark.pyspark.driver.python=/usr/bin/python3 --conf spark.pyspark.python=/usr/bin/python3 --conf spark.yarn.am.memory=4g
```