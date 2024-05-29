# hdfs cluster safe mode and data repair

**When the cluster enters the safe mode, client can only read data, all delete, write requests are not accepted.**

There are two scenarios which the cluster will enter into the safe mode:
- when namenode load `fsimage` and `edits`
- when namenode receives datanode registration

##  Safe mode exit condition config

We can change the default safe mode exit condition config, there are three principal config

```shell
# the available datanode number in the cluster, the default value is 0, it means if there is 1 datanode>0, exit safe mode
dfs.namenode.safemode.min.datanodes

# the replicate number percentage, the default value is 0.999f, only allows 1 missing replica
dfs.namenode.safemode.threshold-pct

# stable stat duration, the default value is 30000 millis (30 seconds). If the cluster in stable stat more than 30 secs
# exit the safe mode
dfs.namenode.safemode.extension


```

## Useful commands

```shell
# get the safe mode state
hdfs dfsadmin -safemode get

# output example
Safe mode is OFF

# enter safe mode
hdfs dfsadmin -safemode enter

Safe mode is ON

# exit safe mode
hdfs dfsadmin -safemode leave

Safe mode is OFF

# wait the clust exit the safe mode, then execute the following commands
hdfs dfsadmin -safemode wait

```

For example, the below script will wait the cluster to exit safe mode, then start the write data process


```shell
# vim safe_write.sh
hdfs dfsadmin -safemode wait
hdfs dfs -put /tmp/toto.txt /hdfs
```
