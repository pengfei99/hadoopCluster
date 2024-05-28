#!/bin/bash

# check arg numbers
if [ $# -lt 1 ]
then
  echo Not enough Argument
  exit;
fi

# 2. loop through host list
for host in spark-w01 spark-w02
do
  echo =========================== $host ==============================

  # 3. loop through the give file list, sync it one by one
  for command in $@
  do
     # 4. run the commands
    ssh $host "$command"
  done
done