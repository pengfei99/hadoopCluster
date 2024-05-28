#!/bin/bash

# 1. check arg numbers
if [ $# -lt 1 ]
then
  echo Not enough Argument
  exit;
fi

# 2. build full command with all args
for arg in $@
do
     command="$command $arg"
done
echo $commad

# 3. loop through host list
for host in spark-w01 spark-w02
do
  echo =========================== $host ==============================
  # 4. run the commands
  ssh $host "$command"
done