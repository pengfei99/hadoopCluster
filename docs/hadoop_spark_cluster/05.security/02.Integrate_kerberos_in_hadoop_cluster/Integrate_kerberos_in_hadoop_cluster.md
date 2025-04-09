# Integrate kerberos into a hadoop cluster 

In this tutorial, we will show how to integrate kerberos into a hadoop cluster. The goal is to use the kerberos tickets
to authenticate users, hosts(e.g. namenode, datanode, resourceManager, etc.) and services(e.g. hdfs, yarn). 

We have different strategy for different kinds of users. For service account, we will generate `.keytab` files to generate
kerberos tickets automatically. For user account, a password maybe required to generate the ticket.
 
## 1. Prerequisite

Before we start, we need to clarify the hadoop cluster context. Because the `AD/Ldap account` and `kerberos principal`
naming conventions strongly depends on the cluster architecture.

Suppose we have three servers, in each server we run different services:
- spark-m01.casdds.casd: name-node(hdfs), resource-manager(yarn), history-server(spark)
- spark-m02.casdds.casd: data-node(hdfs), node-manager(yarn)
- spark-m03.casdds.casd: data-node(hdfs), node-manager(yarn)

> We suppose you already join these machines into the AD/krb realm. For more details, you can check this 
> [doc](https://github.com/pengfei99/LinuxAdminSys/blob/main/docs/debian_server/os_setup/security/05.Configure_ssh_sssd_AD.md) 

### 1.1 Prepare service account and their keytab

To integrate Kerberos in a Hadoop cluster, we need to secure not only the user authentication, but also the service 
authentication(e.g. hdfs, yarn, etc.). As the service account can't provide password in the prompt, we need to enable
passwordless authentication(.keytabs). We need at least four service principals:

- `host principals`: These principals are used to authenticate the server.
- `hdfs principals`: These principals are used by HDFS services such as `namenode`, and `datanode` to authenticate
- `http principals`: These principals are used by `HDFS webfs` services to authenticate
- `yarn principals`: These principals are used by Yarn services such as `Resource Manager`, and `Node Manager` to authenticate
- `user principal`: User principal is used to access hdfs, and negotiate resources
- `spark principals`: These principals are used by the Spark drivers, and executors to authenticate (Optional, not needed since spark 3.0)

By convention, we recommend you to create `a dedicated AD/Ldap account and kerberos principal for each service`. 
This ensures `secure authentication` and `proper ticket management`. It's also easier to monitor access and avoid 
unexpected situations. Technically, an AD/Ldap account can be associated with one or more kerberos principals.

We also recommend a naming convention for Kerberos principals. Below is a list of normal forms for the principals

```shell
# for host principals
host/<FQDN>@REALM
# for hdfs principals
hdfs/<FQDN>@REALM
# for http principals
http/<FQDN>@REALM
# for yarn principals
yarn/<FQDN>@REALM
# for user principals
<uid>/<FQDN>@REALM
```

Below is a list of all AD/Ldap accounts and kerberos principal you need to create:

| Service	 | Hadoop Role     | Host	                  | Kerberos Principal                     | AD account name |
|----------|-----------------|------------------------|----------------------------------------|-----------------|
| HOST     | None	           | spark-m01.casdds.casd  | host/spark-m01.casdds.casd@CASDDS.CASD | spark-m01       |
| HOST     | None            | spark-m02.casdds.casd  | host/spark-m02.casdds.casd@CASDDS.CASD | spark-m02       |
| HOST     | None            | spark-m03.casdds.casd  | host/spark-m03.casdds.casd@CASDDS.CASD | spark-m03       |
| HDFS     | NameNode	       | spark-m01.casdds.casd  | hdfs/spark-m01.casdds.casd@CASDDS.CASD | hdfs-nn         |
| HDFS     | DataNode	       | spark-m02.casdds.casd	 | hdfs/spark-m02.casdds.casd@CASDDS.CASD | hdfs-dn1        |
| HDFS     | DataNode	       | spark-m03.casdds.casd	 | hdfs/spark-m03.casdds.casd@CASDDS.CASD | hdfs-dn2        |
| HDFS     | HTTP Service    | spark-m01.casdds.casd  | http/spark-m01.casdds.casd@CASDDS.CASD | http-nn         |
| HDFS     | HTTP Service    | spark-m02.casdds.casd	 | http/spark-m02.casdds.casd@CASDDS.CASD | http-dn1        |
| HDFS     | HTTP Service    | spark-m03.casdds.casd	 | http/spark-m03.casdds.casd@CASDDS.CASD | http-dn2        |
| YARN     | ResourceManager | spark-m01.casdds.casd  | yarn/spark-m01.casdds.casd@CASDDS.CASD | yarn-rn         |
| YARN     | NodeManager     | spark-m02.casdds.casd  | yarn/spark-m02.casdds.casd@CASDDS.CASD | yarn-nm1        |
| YARN     | NodeManager     | spark-m03.casdds.casd  | yarn/spark-m03.casdds.casd@CASDDS.CASD | yarn-nm2        |
| Spark    | History Server  | spark-m01.casdds.casd  | jhs/spark-m01.casdds.casd@CASDDS.CASD  | spark-jhs       |


> The AD account name cannot contain special character such as `@` and `.`, so we can't use the principal name as 
> AD account name. 

You can create an AD account in windows with the below command

```shell
# create AD account and kerberos principal
New-ADUser -Name "hdfs-nn" -SamAccountName "hdfs-nn" -UserPrincipalName "nn/spark-m01.casdds.casd@CASDDS.CASD" -Enabled $true -PasswordNeverExpires $true -CannotChangePassword $true -ChangePasswordAtLogon $false -PassThru | Set-ADAccountControl -PasswordNotRequired $true

# create corresponding keytab
ktpass -princ nn/spark-m01.casdds.casd@CASDDS.CASD -mapuser hdfs-nn -crypto ALL -ptype KRB5_NT_PRINCIPAL -pass Password! -out hdfs-nn.keytab
```

After you generate the required keytab files for all principals, you need to copy them to the target server.
For example, for server `spark-m01.casdds.casd@CASDDS.CASD`, you need to copy the keytab file for principals:
- hdfs/spark-m01.casdds.casd@CASDDS.CASD
- http/spark-m01.casdds.casd@CASDDS.CASD
- yarn/spark-m01.casdds.casd@CASDDS.CASD
- jhs/spark-m01.casdds.casd@CASDDS.CASD
- host/spark-m01.casdds.casd@CASDDS.CASD

> The general rule is straightforward, you need to check the host fqdn name in the principals 

You can test the validity of the keytab file by asking a kerberos ticket. Below command is an example

```shell
kinit -kt /etc/hdfs-nn.keytab hdfs/spark-m01.casdds.casd@CASDDS.CASD
```

To show the details of a keytab file, you can use the below command: 

```shell
klist -e -k -t /etc/yarn.keytab

# expected output
Keytab name: FILE: /etc/yarn.keytab
 KVNO Timestamp         Principal
   4 07/18/11 21:08:09 yarn/spark-m02.casdds.casd (AES-256 CTS mode with 96-bit SHA-1 HMAC)
   4 07/18/11 21:08:09 yarn/spark-m02.casdds.casd (AES-128 CTS mode with 96-bit SHA-1 HMAC)
   4 07/18/11 21:08:09 yarn/spark-m02.casdds.casd (ArcFour with HMAC/md5)
   4 07/18/11 21:08:09 host/spark-m02.casdds.casd (AES-256 CTS mode with 96-bit SHA-1 HMAC)
   4 07/18/11 21:08:09 host/spark-m02.casdds.casd (AES-128 CTS mode with 96-bit SHA-1 HMAC)
   4 07/18/11 21:08:09 host/spark-m02.casdds.casd (ArcFour with HMAC/md5)
```



### 1.2 Merge the keytab files

To avoid managing many keytab files, you can merge the multi keytab files into one by using `ktutil` tool.

```shell
# start a ktuitl shell with sudo right
sudo ktutil

# load credentials from the keytab files
rkt /tmp/yarnm02.keytab
rkt /tmp/hostm02.keytab

# output the loaded credential to a new keytable file
wkt /tmp/merged.keytab

# exit the ktuitl shell
q
```

You can test the content of the merged keytab file with the below command

```shell
sudo klist -k /tmp/merged.keytab
``` 

### 1.3. Check if the hadoop servers are in the AD DNS

Normally, when the linux servers have joined the AD/Krb realm, their AD/DNS configuration are done automatically.

Just to make sure, you can open the DNS manager on the `Domain controller` where AD/Krb is located.
Below figure is an example of the `DNS manager GUI`

![ad_dns_manager.png](../../../images/ad_dns_manager.png)

You need to check the `value of FQDN and ip` for each server in `forward and reverse lookup zones`.

Below figure is an example for the Forward loopup zone definition of a server

![ad_dns_server_spec.png](../../../images/ad_dns_server_spec.png)

## 1.4. Check kerberos client

Normally, you should have a valid krb5 client and config on each hadoop node.

Below is an example of the krb5 client conf(`/etc/krb5.conf`).


```ini
[libdefaults]
default_realm = CASDDS.CASD
default_tkt_enctypes = aes256-cts-hmac-sha1-96 aes128-cts-hmac-sha1-96
default_tgs_enctypes = aes256-cts-hmac-sha1-96 aes128-cts-hmac-sha1-96
permitted_enctypes   = aes256-cts-hmac-sha1-96 aes128-cts-hmac-sha1-96
kdc_timesync = 1
ccache_type = 4
forwardable = true
ticket_lifetime = 24h
dns_lookup_realm = true
dns_lookup_kdc = true

#allow_weak_crypto = true

[realms]
CASDDS.CASD = {
    kdc = 10.50.5.64
    admin_server = 10.50.5.64
}

[domain_realm]
.CASDDS.CASD = CASDDS.CASD
CASDDS.CASD = CASDDS.CASD
```
> You can enable allow_weak_crypto = true, if the AD/Krb can't use advance crypto algorithm


## 2. Enable SSL in the hadoop cluster

To secure communication between services in the hadoop cluster, we can enable SSL.

### 2.1 Generate certificate

Generate a key pair and store it in a java key store
```shell
sudo keytool -genkeypair \
  -alias hadoop \
  -keyalg RSA \
  -keysize 2048 \
  -validity 365 \
  -keystore /opt/hadoop/keystore.jks \
  -storepass changeit
```

Check the keystore content 
```shell
sudo keytool -list -keystore /opt/hadoop/keystore.jks -storepass changeit
```

Export the certificate

```shell
sudo keytool -export -alias hadoop -keystore /opt/hadoop/keystore.jks -file /opt/hadoop/hadoop-cert.pem -storepass changeit
```

### 2.2 Configuration of SSL in hadoop cluster

The ssl configuration file in hadoop cluster is `$HADOOP_HOME/etc/hadoop/ssl-server.xml` and 
`$HADOOP_HOME/etc/hadoop/ssl-client.xml`. In our case, we only need to modify `ssl-server.xml`.

Below is an example of the `ssl-server.xml`
```shell
sudo vim ssl-server.xml
```
Add the below lines
```xml
<configuration>
  <property>
    <name>ssl.server.keystore.location</name>
    <value>/opt/hadoop/keystore.jks</value>
  </property>
  <property>
    <name>ssl.server.keystore.password</name>
    <value>changeit</value>
  </property>
  <property>
    <name>ssl.server.keystore.keypassword</name>
    <value>changeit</value>
  </property>
  <property>
    <name>ssl.server.keystore.type</name>
    <value>jks</value>
    <description>(Optionnel) Format du keystore (par défaut « jks »).</description>
  </property>
  <property>
    <name>ssl.server.exclude.cipher.list</name>
    <value>
      TLS_ECDHE_RSA_WITH_RC4_128_SHA,
      SSL_DHE_RSA_EXPORT_WITH_DES40_CBC_SHA,
      SSL_RSA_WITH_DES_CBC_SHA,
      SSL_DHE_RSA_WITH_DES_CBC_SHA,
      SSL_RSA_EXPORT_WITH_RC4_40_MD5,
      SSL_RSA_EXPORT_WITH_DES40_CBC_SHA,
      SSL_RSA_WITH_RC4_128_MD5
    </value>
    <description>(Optionnel) Liste des suites de chiffrement faibles à exclure.</description>
  </property>
</configuration>
```

> This needs to be done all nodes of the hadoop cluster

## 2. Integrate kerberos in to Hadoop cluster

Here, we suppose you already have a working hadoop cluster, the below steps only shows how to integrate kerberos into
Hadoop. If you want to learn how to deploy a hadoop cluster, you need to follow this 
[doc](https://github.com/pengfei99/hadoopCluster/tree/main/docs/hadoop_spark_cluster/02.Installation)

### 2.1 Edit hadoop-env.sh

The `hadoop-env.sh` file specifies all environment variables related to the hadoop cluster

Below is a list of variables you need to check 
```shell
export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
export HADOOP_OPTS="-Djava.net.preferIPv4Stack=true -Djava.security.debug=gssloginconfig,configfile,configparser,logincontext"
# use krb client config 
export HADOOP_OPTS="-Djava.security.krb5.conf=/etc/krb5.conf $HADOOP_OPTS"
export HDFS_NAMENODE_USER=hadoop
export HDFS_DATANODE_USER=hadoop
export HDFS_SECONDARYNAMENODE_USER=hadoop
export JSVC_HOME=$(dirname $(which jsvc))
export HADOOP_CONF_DIR=/opt/hadoop/etc/hadoop
export HADOOP_SECURITY_LOGGER=INFO,RFAS,console
export JAVA_TOOL_OPTIONS="$JAVA_TOOL_OPTIONS --add-opens=java.base/sun.net.dns=ALL-UNNAMED"
```


### 2.2 Updates the security configuration of JDK

For kerberos interoperate well with JDK, we need to update the default security conf of the JDK. 

```shell
sudo vim $JAVA_HOME/conf/security/java.security

# in our case, we use openjdk in debian 11. We can use the absolute path
sudo vim /usr/lib/jvm/java-11-openjdk-amd64/conf/security/java.security

# you need to add the below lines
crypto.policy=unlimited
sun.security.krb5.disableReferrals=true
```

> By default, the `RC4` encryption algo is disabled, because it's weak. But some Windows server still uses it.
> You can find the line `jdk.jar.disabledAlgorithms` and `jdk.tls.disabledAlgorith`, then remove the `RC4` from the 
> disabled algo list.


### 2.3 Update the hadoop service configuration

#### 2.3.1 For Name nodes

For `Name nodes`, you need to edit the below config files:
- core-site.xml
- hdfs-site.xml
- yarn-site.xml

The below modification is made in `spark-m01.casdds.casd`

```shell
sudo vim core-site.xml 

# add the below lines
<configuration>
  <property>
    <name>hadoop.ssl.server.conf</name>
    <value>/opt/hadoop/etc/hadoop/ssl-server.xml</value>
  </property>
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
    <property>
        <name>hadoop.security.group.mapping</name>
        <value>org.apache.hadoop.security.ShellBasedUnixGroupsMapping</value>
    </property>
  <property>
    <name>hadoop.http.authentication.type</name>
    <value>kerberos</value>
  </property>
  <property>
    <name>hadoop.http.authentication.kerberos.principal</name>
    <value>http/spark-m01.casdds.casd@CASDDS.CASD</value>
  </property>
  <property>
    <name>hadoop.http.authentication.kerberos.keytab</name>
    <value>/etc/httpm01.keytab</value>
  </property>
  <property>
    <name>hadoop.http.filter.initializers</name>
    <value>org.apache.hadoop.security.AuthenticationFilterInitializer</value>
  </property>
  <property>
    <name>hadoop.security.auth_to_local</name>
    <value>
      RULE:[2:$1@$0](.*@casdds\.casd)s/@casdds\.casd//
      RULE:[1:$1]
      DEFAULT
    </value>
    <description>Mapping du principal Kerberos vers le nom d’utilisateur local.</description>
  </property>
</configuration>
```

```shell
sudo vim hdfs-site.xml

# add the below lines
<configuration>
  <property>
    <name>dfs.https.server.keystore.resource</name>
    <value>ssl-server.xml</value>
  </property>
  <property>
    <name>dfs.http.policy</name>
    <value>HTTPS_ONLY</value>
  </property>
  <property>
    <name>dfs.https.port</name>
    <value>50470</value>
  </property>
  <property>
    <name>dfs.data.transfer.protection</name>
    <value>authentication</value>
  </property>
  <property>
    <name>dfs.secondary.https.port</name>
    <value>50490</value>
    <description>Port HTTPS pour le secondary-namenode.</description>
  </property>
  <property>
    <name>dfs.https.address</name>
    <value>spark-m01.casdds.casd:50470</value>
    <description>Adresse HTTPS d’écoute du Namenode.</description>
  </property>
  <property>
    <name>dfs.encrypt.data.transfer</name>
    <value>true</value>
  </property>
  <property>
    <name>dfs.replication</name>
    <value>3</value>
  </property>
  <property>
    <name>dfs.namenode.name.dir</name>
    <value>file:///opt/hadoop/hadoop_tmp/hdfs/data</value>
  </property>
  <property>
    <name>dfs.datanode.data.dir</name>
    <value>file:///opt/hadoop/hadoop_tmp/hdfs/data</value>
  </property>
  <property>
    <name>dfs.permissions</name>
    <value>true</value>
    <description>Activation de la vérification des permissions sur HDFS.</description>
  </property>
  <property>
    <name>dfs.namenode.handler.count</name>
    <value>100</value>
    <description>Augmentation de la file d’attente pour gérer davantage de connexions clients.</description>
  </property>
  <property>
    <name>ipc.server.max.response.size</name>
    <value>5242880</value>
  </property>
  <property>
    <name>dfs.permissions.supergroup</name>
    <value>hadoop</value>
    <description>Nom du groupe des super-utilisateurs.</description>
  </property>
  <property>
    <name>dfs.cluster.administrators</name>
    <value>hadoop</value>
    <description>ACL pour l’accès aux servlets par défaut de HDFS.</description>
  </property>
  <property>
    <name>dfs.access.time.precision</name>
    <value>0</value>
    <description>Désactivation de la mise à jour des temps d’accès pour les fichiers HDFS.</description>
  </property>
  <property>
    <name>dfs.block.access.token.enable</name>
    <value>true</value>
    <description>Activation des tokens d’accès pour sécuriser l’accès aux datanodes.</description>
  </property>
  <property>
    <name>ipc.server.read.threadpool.size</name>
    <value>5</value>
  </property>
  <property>
    <name>dfs.namenode.http-address</name>
    <value>spark-m01.casdds.casd:9870</value>
  </property>
  <property>
    <name>dfs.namenode.kerberos.principal</name>
    <value>hdfs/spark-m01.casdds.casd@CASDDS.CASD</value>
  </property>
  <property>
    <name>dfs.namenode.keytab.file</name>
    <value>/etc/hdfsm01.keytab</value>
  </property>
  <property>
    <name>dfs.secondary.namenode.kerberos.principal</name>
    <value>hdfs/spark-m01.casdds.casd@CASDDS.CASD</value>
  </property>
  <property>
    <name>dfs.secondary.namenode.keytab.file</name>
    <value>/etc/hdfsm01.keytab</value>
  </property>
  <property>
    <name>dfs.permissions.enabled</name>
    <value>true</value>
  </property>
</configuration>
```

```shell
sudo vim yarn-site.xml

# add the below lines
<configuration>
  <property>
    <name>yarn.nodemanager.aux-services</name>
    <value>mapreduce_shuffle</value>
  </property>
  <property>
    <name>yarn.nodemanager.aux-services.mapreduce.shuffle.class</name>
    <value>org.apache.hadoop.mapred.ShuffleHandler</value>
  </property>
  <property>
    <name>yarn.resourcemanager.hostname</name>
    <value>spark-m01.casdds.casd</value>
  </property>
  <property>
    <name>yarn.nodemanager.resource.cpu-vcores</name>
    <value>2</value>
  </property>
  <property>
    <name>yarn.nodemanager.resource.memory-mb</name>
    <value>2048</value>
  </property>
  <property>
    <name>yarn.scheduler.maximum-allocation-mb</name>
    <value>2048</value>
  </property>
  <property>
    <name>yarn.scheduler.minimum-allocation-mb</name>
    <value>512</value>
  </property>
  <property>
    <name>yarn.resourcemanager.principal</name>
    <value>yarn/spark-m01.casdds.casd@CASDDS.CASD</value>
  </property>
  <property>
    <name>yarn.resourcemanager.keytab</name>
    <value>/etc/yarnm01.keytab</value>
  </property>
  <property>
    <name>yarn.timeline-service.principal</name>
    <value>yarn/spark-m01.casdds.casd@CASDDS.CASD</value>
  </property>
  <property>
    <name>yarn.timeline-service.keytab</name>
    <value>/etc/yarnm01.keytab</value>
  </property>
</configuration>
```
#### 2.3.2 For DataNode

For data nodes, you need to edit the below configuration files:
- core-site.xml
- hdfs-site.xml
- yarn-site.xml
- 
The below modification is made in `spark-m02.casdds.casd`

> You need to do similar modification in the `spark-m03`, remember to adapt the principal name and keytab path
>
```shell
sudo vim core-site.xml

# add the below lines
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
  <property>
    <name>hadoop.ssl.server.conf</name>
    <value>ssl-server.xml</value>
  </property>
  <property>
    <name>hadoop.security.auth_to_local</name>
    <value>
      RULE:[2:$1@$0](.*@CASDDS\.CASD)s/@CASDDS\.CASD//
      RULE:[1:$1]
      DEFAULT
    </value>
    <description>Mapping du principal Kerberos vers l’utilisateur local.</description>
  </property>
</configuration>
```

```shell
sudo vim hdfs-site.xml

# add the below lines
<configuration>
  <property>
    <name>dfs.https.server.keystore.resource</name>
    <value>ssl-server.xml</value>
  </property>
  <property>
    <name>dfs.http.policy</name>
    <value>HTTPS_ONLY</value>
  </property>
  <property>
    <name>dfs.https.port</name>
    <value>50470</value>
  </property>
  <property>
    <name>dfs.data.transfer.protection</name>
    <value>authentication</value>
  </property>
  <property>
    <name>dfs.secondary.https.port</name>
    <value>50490</value>
    <description>Port HTTPS pour le secondary-namenode.</description>
  </property>
  <property>
    <name>dfs.https.address</name>
    <value>ip-10-50-5-203.casdds.casd:50470</value>
    <description>Adresse HTTPS d’écoute du Namenode sur le DataNode.</description>
  </property>
  <property>
    <name>dfs.encrypt.data.transfer</name>
    <value>true</value>
  </property>
  <property>
    <name>dfs.replication</name>
    <value>3</value>
  </property>
  <property>
    <name>dfs.namenode.name.dir</name>
    <value>file:///opt/hadoop/hadoop_tmp/hdfs/data</value>
  </property>
  <property>
    <name>dfs.datanode.data.dir</name>
    <value>file:///opt/hadoop/hadoop_tmp/hdfs/data</value>
  </property>
  <property>
    <name>dfs.datanode.kerberos.principal</name>
    <value>hdfs/spark-m02.casdds.casd@CASDDS.CASD</value>
  </property>
  <property>
    <name>dfs.datanode.keytab.file</name>
    <value>/etc/hdfsm02.keytab</value>
  </property>
  <property>
    <name>dfs.namenode.kerberos.principal</name>
    <value>hdfs/spark-m01.casdds.casd@CASDDS.CASD</value>
  </property>
  <property>
    <name>dfs.namenode.keytab.file</name>
    <value>/etc/hdfsm01.keytab</value>
  </property>
  <property>
    <name>dfs.permissions</name>
    <value>true</value>
    <description>Activation de la vérification des permissions sur HDFS.</description>
  </property>
  <property>
    <name>dfs.permissions.supergroup</name>
    <value>hadoop</value>
    <description>Nom du groupe des super-utilisateurs.</description>
  </property>
  <property>
    <name>ipc.server.max.response.size</name>
    <value>5242880</value>
  </property>
  <property>
    <name>dfs.block.access.token.enable</name>
    <value>true</value>
    <description>Activation des tokens d’accès pour l’accès aux datanodes.</description>
  </property>
  <property>
    <name>dfs.datanode.data.dir.perm</name>
    <value>750</value>
    <description>Permissions requises sur les répertoires de données.</description>
  </property>
  <property>
    <name>dfs.access.time.precision</name>
    <value>0</value>
    <description>Désactivation de la mise à jour des temps d’accès pour les fichiers HDFS.</description>
  </property>
  <property>
    <name>dfs.cluster.administrators</name>
    <value>hadoop</value>
    <description>ACL pour l’accès aux servlets par défaut de HDFS.</description>
  </property>
  <property>
    <name>ipc.server.read.threadpool.size</name>
    <value>5</value>
  </property>
</configuration>
```

```shell
sudo vim yarn-site.xml

# add the below lines
<configuration>
  <property>
    <name>yarn.nodemanager.aux-services</name>
    <value>mapreduce_shuffle</value>
  </property>
  <property>
    <name>yarn.nodemanager.aux-services.mapreduce.shuffle.class</name>
    <value>org.apache.hadoop.mapred.ShuffleHandler</value>
  </property>
  <property>
    <name>yarn.nodemanager.hostname</name>
    <value>spark-m02.casdds.casd</value>
  </property>
  <property>
    <name>yarn.resourcemanager.hostname</name>
    <value>spark-m01.casdds.casd</value>
  </property>
  <property>
    <name>yarn.nodemanager.resource.cpu-vcores</name>
    <value>2</value>
  </property>
  <property>
    <name>yarn.nodemanager.resource.memory-mb</name>
    <value>2048</value>
  </property>
  <property>
    <name>yarn.scheduler.maximum-allocation-mb</name>
    <value>2048</value>
  </property>
  <property>
    <name>yarn.scheduler.minimum-allocation-mb</name>
    <value>512</value>
  </property>
  <property>
    <name>yarn.resourcemanager.principal</name>
    <value>yarn/spark-m01.casdds.casd@CASDDS.CASD</value>
  </property>
  <property>
    <name>yarn.resourcemanager.keytab</name>
    <value>/etc/yarnm01.keytab</value>
  </property>
  <property>
    <name>yarn.timeline-service.principal</name>
    <value>yarn/spark-m02.casdds.casd@CASDDS.CASD</value>
  </property>
  <property>
    <name>yarn.timeline-service.keytab</name>
    <value>/etc/yarnm02.keytab</value>
  </property>
  <property>
    <name>yarn.nodemanager.principal</name>
    <value>yarn/spark-m02.casdds.casd@CASDDS.CASD</value>
  </property>
  <property>
    <name>yarn.nodemanager.keytab</name>
    <value>/etc/yarnm02.keytab</value>
  </property>
  <property>
    <name>yarn.timeline-service.http-authentication.type</name>
    <value>kerberos</value>
  </property>
  <property>
    <name>yarn.nodemanager.vmem-check-enabled</name>
    <value>true</value>
  </property>
</configuration>
```



## Refresh User to group mappings

```shell
hdfs dfsadmin -refreshUserToGroupsMappings
```


## Reference

- https://hadoop.apache.org/docs/stable/hadoop-project-dist/hadoop-common/SecureMode.html
- http://docs.cloudera.com.s3-website-us-east-1.amazonaws.com/HDPDocuments/HDP3/HDP-3.1.5/security-reference/content/kerberos_nonambari_adding_security_information_to_configuration_files.html


## Repo test

https://github.com/CASD-EU/admin_sys/tree/test/dev/roles
