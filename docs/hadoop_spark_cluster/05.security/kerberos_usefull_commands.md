# Kerberos useful commands



## Generate a keytab file

### User side generation
User can also generate a keytab file, because he knows the password and credential.

The below scripts are tested in debian 11
```shell
# start a ktutil shell 
ktutil 

# add an entry to keytab cache
addent -password -p pliu@CASDDS.CASD -k 1 -e aes256-cts-hmac-sha1-96

# output the keytab cache to a keytab file
wkt ~/pliu-user.keytab
```

The options are:
 - `-password`: Allows manual password entry. 
 - `-p hadoop-user@EXAMPLE.COM`: The Kerberos principal of the keytab.
 - `-k 1`: The key version number (increment if needed).
 - `-e aes256-cts-hmac-sha1-96`: The encryption type.


## Setup a custom kinit script

```shell
# edit the .bashrc file
vim ~/.bashrc


# add the below lines
export KRB5_CLIENT_KTNAME=~/$USER-user.keytab
export KRB5CCNAME=/tmp/krb5cc_$(id -u)
export KRB5_PRINCIPAL="$USER@CASDDS.CASD"
alias kinit-default='kinit -kt $KRB5_CLIENT_KTNAME $KRB5_PRINCIPAL'

```