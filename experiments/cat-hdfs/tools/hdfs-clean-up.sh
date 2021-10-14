#!/bin/bash

#########################################################

# Update these variables:

USER="gsd"
WORKING_DIR="/mnt/nvme"
VOL_LOCAL="$WORKING_DIR/local"
VOL_DFS="/home/$USER/dfs"
CAT_HDFS_DIR="/home/$USER/cat-hdfs"


#########################################################

CONF_DIR="$CAT_HDFS_DIR/conf-files"
HADOOP_PATH="$VOL_DFS/hadoop"
HADOOP_TMP_DIR="$VOL_DFS/app/hadoop/tmp"
HADOOP_NAMENODE_DIR="$VOL_LOCAL/hadoop_store/hdfs/namenode"
HADOOP_DATANODE_DIR="$VOL_LOCAL/hadoop_store/hdfs/datanode"

declare -a hosts
readarray -t hosts < "$CONF_DIR/hosts"
MASTER_ROW=(${hosts[0]})
MASTER="${MASTER_ROW[0]}"
MASTER_IP="${MASTER_ROW[1]}"

#########################################################


function stop_hdfs {
	ssh $USER@$MASTER "$HADOOP_PATH/sbin/stop-dfs.sh"
}


function format_hdfs {
  echo "hdfs-clean-up:format-hdfs"
  ssh $USER@$MASTER 'echo "y" | '$HADOOP_PATH'/bin/hdfs namenode -format'
}

# This command should be run with root:root
function clean_cache {
    for (( i=0; i<${#hosts[@]}; i++ )); do
        host_row=(${hosts[$i]})
        echo "hdfs-clean-up:clean-cache:$USER@${host_row[0]}"
        ssh $USER@${host_row[1]} "free -h"
        ssh $USER@${host_row[1]} "sudo sh -c \"sync; echo 3 > /proc/sys/vm/drop_caches; swapoff -a && swapon -a\"";
        ssh $USER@${host_row[1]} "free -h"
    done
}

function clean_tmp_files {
    for (( i=0; i<${#hosts[@]}; i++ )); do
        host_row=(${hosts[$i]})
        echo "hdfs-clean-up:clean_tmp_files:$USER@${host_row[0]}"
        ssh $USER@${host_row[1]} "rm -rf /tmp/hadoop-$USER/"
        ssh $USER@${host_row[1]} "rm -rf /tmp/hsperfdata_$USER/"
    done
}

function clean_logs {
    for (( i=0; i<${#hosts[@]}; i++ )); do
        host_row=(${hosts[$i]})
        echo "hdfs-clean-up:clean_logs:$USER@${host_row[0]}"
        ssh $USER@${host_row[1]} "rm -rf $VOL_DFS/hadoop/logs/"
        ssh $USER@${host_row[1]} "rm -rf $VOL_DFS/dfs-perf/logs/"
    done
}

function clean_datanodes {
    for (( i=0; i<${#hosts[@]}; i++ )); do
        host_row=(${hosts[$i]})
        echo "hdfs-clean-up:clean_datanodes:$USER@${host_row[0]}"
        ssh $USER@${host_row[1]} "rm -rf $HADOOP_DATANODE_DIR/*"
        ssh $USER@${host_row[1]} "rm -rf $HADOOP_NAMENODE_DIR/*"
    done
}

function clean_all {
  stop_hdfs
  clean_logs
  clean_datanodes
  clean_tmp_files
  format_hdfs
}

"$@"