# Configure hadoop client with kerberos

In this tutorial, we will show how to configure a hadoop client to connect a `keberos secured Hadoop cluster`.

Suppose the Hadoop cluster has the below architecture:

```text
10.50.5.199	hadoop-client.casdds.casd	# hadoop-client
10.50.5.203	spark-m01.casdds.casd	# name node
10.50.5.204     spark-m02.casdds.casd   # data node 1
10.50.5.205     spark-m03.casdds.casd  # data node 2
```
## Install kerberos client

The below commands are tested in debian 11

```shell
sudo apt update
sudo apt install krb5-user

# config keberos client
sudo vim /etc/krb5.conf

```
Add the below content to the file
```ini

[libdefaults]
        default_realm = CASDDS.CASD

        default_tkt_enctypes = aes256-cts-hmac-sha1-96 aes128-cts-hmac-sha1-96
        default_tgs_enctypes = aes256-cts-hmac-sha1-96 aes128-cts-hmac-sha1-96
        permitted_enctypes   = aes256-cts-hmac-sha1-96 aes128-cts-hmac-sha1-96
        kdc_timesync = 1
        ccache_type = 4
        forwardable = true
        proxiable = true
        ticket_lifetime = 24h
        dns_lookup_realm = true
        dns_lookup_kdc = true
        dns_canonicalize_hostname = false
        rdns = false
         allow_weak_crypto = true

[realms]
        CASDDS.CASD = {
                kdc = 10.50.5.64
                admin_server = 10.50.5.64
        }

[domain_realm]
        .casdds.casd = CASDDS.CASD
        casdds.casd = CASDDS.CASD
```

## check your kerberos config

```shell
kinit pengfei@CASDDS.CASDDS

# if you have a keytab file, you can use the below command
kinit -kt /home/pengfei/hadoop-pengfei.keytab pengfei@CASDDS.CASDDS

klist
```


## Install hadoop client packages

Here we recommend you to install the hadoop package via the `tar ball`, because the package from the system package manager
may not be compatible with hadoop cluster.

You can find all hadoop releases from this [page](https://hadoop.apache.org/releases.html). As our hadoop cluster use
version `3.3.6`. Our client must be version `3.3.6` too.

> Install a jdk, and set up a JAVA_HOME before doing the below command, because hadoop needs JDK to run

```shell
# check jdk and java home
jave -verion
echo $JAVA_HOME

# download the tar ball
wget https://dlcdn.apache.org/hadoop/common/hadoop-3.3.6/hadoop-3.3.6.tar.gz

# put the tar ball in /opt/hadoop
sudo mkdir -p /opt/hadoop

sudo mv hadoop-3.3.6.tar.gz /opt/hadoop

cd /opt/hadoop

sudo tar -xzvf hadoop-3.3.6.tar.gz

# add hadoop to bash
sudo vim /etc/profile.d/hadoop.sh

# add the below lines into the file
export HADOOP_HOME=/opt/hadoop/hadoop-3.3.6
export PATH=$PATH:$HADOOP_HOME/bin:$HADOOP_HOME/sbin
export HADOOP_CONF_DIR=/opt/hadoop/hadoop-3.3.6/etc/hadoop
export HADOOP_CLASSPATH=`$HADOOP_HOME/bin/hadoop classpath`

# load the new bash config
source /etc/profile.d/hadoop.sh
```

## Configure the hadoop client

You will need to edit three config file in `/opt/hadoop/hadoop-3.3.6/etc/hadoop`:
- core-site.xml
- hdfs-site.xml
- yarn-site.xml

Below templates are the minimum example for the client to work, for extra features you need to add more config:

### core-site.xml example

```xml
<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>


<configuration>
	<property>
        <name>fs.defaultFS</name>
        <value>hdfs://spark-m01.casdds.casd:9000</value>
    </property>
	<property>
        <name>hadoop.security.authentication</name>
        <value>kerberos</value>
    </property>
    <property>
        <name>hadoop.security.authorization</name>
        <value>true</value>
    </property>
</configuration>

```

### hdfs-site.xml example

```xml
<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>


<configuration>
 <property>
        <name>dfs.replication</name>
        <value>3</value>
</property>
<property>
    <name>dfs.namenode.kerberos.principal</name>
    <value>hdfs/spark-m01.casdds.casd@CASDDS.CASD</value>
  </property>
</configuration>

```

### yarn-site.xml

```xml
<?xml version="1.0"?>

<configuration>
  <property>
    <name>yarn.nodemanager.hostname</name>
    <value>spark-m02.casdds.casd</value>
  </property>
  <property>
    <name>yarn.resourcemanager.hostname</name>
    <value>spark-m01.casdds.casd</value>
  </property>
  <property>
    <name>yarn.resourcemanager.principal</name>
    <value>yarn/spark-m01.casdds.casd@CASDDS.CASD</value>
  </property>
  <property>
    <name>yarn.timeline-service.principal</name>
    <value>yarn/spark-m02.casdds.casd@CASDDS.CASD</value>
  </property>
  <property>
    <name>yarn.nodemanager.principal</name>
    <value>yarn/spark-m02.casdds.casd@CASDDS.CASD</value>
  </property>
  <property>
    <name>yarn.timeline-service.http-authentication.type</name>
    <value>kerberos</value>
  </property>
</configuration>

```

## Test your hadoop client

```shell

# get a ticket
kinit -kt /home/pengfei/hadoop-pengfei.keytab pengfei@CASDDS.CASDDS
# check hdfs
hdfs dfs -ls /

# check yarn 
yarn node -list

# check spark
spark-submit \
  --master yarn \
  --deploy-mode cluster \
  --principal pengfei@CASDDS.CASDDS \
  --keytab /home/pengfei/hadoop-pengfei.keytab \
  --class eu.casd.MySparkApp \
  my-spark-app.jar
```

> Ask Eric, Ticket Renewal is required for Long-Running Spark Jobs

Kerberos tickets expire after a certain time (e.g., 24 hours). Using a keytab allows Spark to automatically renew the Kerberos ticket while running.

