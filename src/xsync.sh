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
  for file in $@
  do
     # 4. check if the file exists
     if [ -e $file ]
         then
           # 5. get the parent dir
           pdir=$(cd -P $(dirname $file); pwd)
           # 6. get the filename
           fname=$(basename $file)
           ssh $host "mkdir -p $pdir"
           rsync -av $pdir/$fname $host:$pdir
          else
            echo $file does not exists!
     fi
  done
done