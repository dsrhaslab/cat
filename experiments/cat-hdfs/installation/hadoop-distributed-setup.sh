#!/bin/bash

#########################################################

# Update these variables:
USER="gsd"
VOL_LOCAL="/mnt/nvme/local"
VOL_DFS="dfs"
HADOOP_VERSION=2.7.1
JAVA_HOME=java-8-openjdk-amd64
CAT_HDFS_DIR="/home/$USER/cat-hdfs"

#########################################################

HOST=$(hostname)
CONF_DIR="$CAT_HDFS_DIR/conf-files"
HADOOP_PATH="/home/$USER/$VOL_DFS/hadoop"

HADOOP_TMP_DIR="/home/$USER/$VOL_DFS/app/hadoop/tmp"
HADOOP_NAMENODE_DIR="$VOL_LOCAL/hadoop_store/hdfs/namenode"
HADOOP_DATANODE_DIR="$VOL_LOCAL/hadoop_store/hdfs/datanode"

declare -a hosts
readarray -t hosts < "$CONF_DIR/hosts"
MASTER_ROW=(${hosts[0]})
MASTER="${MASTER_ROW[0]}"
MASTER_IP="${MASTER_ROW[1]}"

#########################################################

function generate_cluster_ssh_key {
  echo "Master - $MASTER."
  if [ "$HOST" = "$MASTER" ]; then
    echo "$HOST: I AM THE MASTER."
    mkdir -p /home/$USER/.ssh/
    cd /home/$USER/.ssh/
    # generate a passwordless ssh-key
    ssh-keygen -t rsa -P "" -f id_rsa
    # copy ssh-key to the authorized keys
    cat /home/$USER/.ssh/id_rsa.pub >> /home/$USER/.ssh/authorized_keys
    chmod 600 authorized_keys
    cd /home/$USER/

    # Copy the public key to each slave
    hlen=${#hosts[@]}
    # Send to all hosts minus the master
    for (( i=1; i<${hlen}; i++ )); do
      host_row=(${hosts[$i]})
      echo "Host: ${host_row[0]}"
      ssh-copy-id -i /home/$USER/.ssh/id_rsa.pub ${host_row[1]}
    done
  else
    echo "$HOST: I AM A SLAVE."
  fi
}

function download_hadoop_source {
  # Donwload from sources
  cd /home/$USER/
  wget https://archive.apache.org/dist/hadoop/core/hadoop-$HADOOP_VERSION/hadoop-$HADOOP_VERSION.tar.gz
  tar xvzf hadoop-$HADOOP_VERSION.tar.gz
  mkdir -p $HADOOP_PATH
  mv hadoop-$HADOOP_VERSION/* $HADOOP_PATH
  rmdir hadoop-$HADOOP_VERSION
  rm hadoop-$HADOOP_VERSION.tar.gz
  # Create required directories
  mkdir -p $HADOOP_TMP_DIR
  mkdir -p $HADOOP_NAMENODE_DIR
  mkdir -p $HADOOP_DATANODE_DIR
}

function set_hadoop_environment {
  # Add Haddop variables to .bashrc file (of $USER)
  echo "" >> /home/$USER/.bashrc
  echo "#HADOOP VARIABLES START" >> /home/$USER/.bashrc
  echo "export JAVA_HOME=/usr/lib/jvm/$JAVA_HOME" >> /home/$USER/.bashrc
  echo "export HADOOP_INSTALL=$HADOOP_PATH" >> /home/$USER/.bashrc
  echo "export PATH=\$PATH:\$HADOOP_INSTALL/bin" >> /home/$USER/.bashrc
  echo "export PATH=\$PATH:\$HADOOP_INSTALL/sbin" >> /home/$USER/.bashrc
  echo "export HADOOP_MAPRED_HOME=\$HADOOP_INSTALL" >> /home/$USER/.bashrc
  echo "export HADOOP_COMMON_HOME=\$HADOOP_INSTALL" >> /home/$USER/.bashrc
  echo "export HADOOP_HDFS_HOME=\$HADOOP_INSTALL" >> /home/$USER/.bashrc
  echo "export YARN_HOME=\$HADOOP_INSTALL" >> /home/$USER/.bashrc
  echo "export HADOOP_COMMON_LIB_NATIVE_DIR=\$HADOOP_INSTALL/lib/native" >> /home/$USER/.bashrc
  echo "export HADOOP_OPTS=\"-Djava.library.path=\$HADOOP_INSTALL/lib\"" >> /home/$USER/.bashrc
  echo "#HADOOP VARIABLES END" >> /home/$USER/.bashrc
  source /home/$USER/.bashrc

  sed -i.bak "s@.*export JAVA_HOME=.*@export JAVA_HOME=\/usr\/lib\/jvm\/$JAVA_HOME/@g" $HADOOP_PATH/etc/hadoop/hadoop-env.sh
  echo "set-hadoop-environment: check if the changes were commited to the .bashrc file. If not, source it."
}


function set_site_files {
  general_files=("core" "hdfs" "yarn")
  for file in "${general_files[@]}"; do
    echo "File: = $file-site"
    mv $HADOOP_PATH/etc/hadoop/$file-site.xml $HADOOP_PATH/etc/hadoop/$file-site.xml.bak
    cp $CONF_DIR/site/$file-site.xml $HADOOP_PATH/etc/hadoop/$file-site.xml
  done

  # This command will be only applied in the core-site.xml file. It will define the host of the HDFS-Master and
  # the path for the tmp directory (that will store the temporary files of HDFS such as MapReduce tasks)
  if [ "$HADOOP_VERSION" == "hadoop-2.9.2" ]; then
    sed -i "s#master:#$MASTER_IP:9000#g" "$HADOOP_PATH/etc/hadoop/core-site.xml"
  else
    sed -i "s#master:#$MASTER_IP:54310#g" "$HADOOP_PATH/etc/hadoop/core-site.xml"
  fi
  sed -i "s#<value>hadoop-tmp-dir</value>#<value>$HADOOP_TMP_DIR</value>#g" "$HADOOP_PATH/etc/hadoop/core-site.xml"

  # This command will be only applied in the hdfs-site.xml file. It will define the replication factor and the
  # path for both NameNode and DataNode directories.
  sed -i "s#<value>1</value>#<value>3</value>#g" "$HADOOP_PATH/etc/hadoop/hdfs-site.xml"
  sed -i "s#<value>hdfs-namenode-dir</value>#<value>file:$HADOOP_NAMENODE_DIR</value>#g" "$HADOOP_PATH/etc/hadoop/hdfs-site.xml"
  sed -i "s#<value>hdfs-datanode-dir</value>#<value>file:$HADOOP_DATANODE_DIR</value>#g" "$HADOOP_PATH/etc/hadoop/hdfs-site.xml"

  # This command will be only applied in the yarn-site.xml file
  sed -i "s#master:8030#$MASTER_IP:8030#g" "$HADOOP_PATH/etc/hadoop/yarn-site.xml"
  sed -i "s#master:8032#$MASTER_IP:8032#g" "$HADOOP_PATH/etc/hadoop/yarn-site.xml"
  sed -i "s#master:8088#$MASTER_IP:8088#g" "$HADOOP_PATH/etc/hadoop/yarn-site.xml"
  sed -i "s#master:8031#$MASTER_IP:8031#g" "$HADOOP_PATH/etc/hadoop/yarn-site.xml"
  sed -i "s#master:8033#$MASTER_IP:8033#g" "$HADOOP_PATH/etc/hadoop/yarn-site.xml"

  # master_files=("mapred" "workers")
  if [ "$HOST" = "$MASTER" ]; then
    # Move mapred-site.xml file
    mv $HADOOP_PATH/etc/hadoop/mapred-site.xml $HADOOP_PATH/etc/hadoop/mapred-site.xml.bak
    cp $CONF_DIR/site/mapred-site.xml $HADOOP_PATH/etc/hadoop/mapred-site.xml
    # This command will be only applied in the mapred-site.xml
    sed -i "s#master:54311#$MASTER_IP:54311#g" "$HADOOP_PATH/etc/hadoop/mapred-site.xml"

    workersfile=slaves

    # Move workers file
    mv $HADOOP_PATH/etc/hadoop/$workersfile $HADOOP_PATH/etc/hadoop/$workersfile.bak
    touch $HADOOP_PATH/etc/hadoop/$workersfile
    echo "# NameNodes" >> $HADOOP_PATH/etc/hadoop/$workersfile

    hlen=${#hosts[@]}
    # Print the datanode id of each slave to the workers file
    for (( i=1; i<${hlen}; i++ )); do
    host_row=(${hosts[$i]})
      echo "datanode-$i: ${host_row[1]}"
      echo "${host_row[1]}" >> $HADOOP_PATH/etc/hadoop/$workersfile
    done
  fi

}

function format_namenode {
    if [ "$HOST" = "$MASTER" ]; then
      $HADOOP_PATH/sbin/stop-dfs.sh
      rm -rf $HADOOP_TMP_DIR/*
      echo "y" | hdfs namenode -format
    fi
}

# If the DataNode is not starting it's because after a previous execution (NameNode and DataNode started running),
# the NameNode has been formatted again. That means the metadata from the NameNode has been cleared, and thus, the
# files which have been previously stored in the DataNode, are still in the DataNode and it does not have any idea
# where to send the block reports since the NameNode has been formatted. After doing the following commands,
# you are good to format the NameNode and restart the DFS.
function format_datanode {
  $HADOOP_PATH/sbin/stop-dfs.sh
  rm -Rf $VOL_LOCAL/hadoop_store/hdfs/datanode/*
}

function start_dfs {
  if [ "$HOST" = "$MASTER" ]; then
    $HADOOP_PATH/sbin/start-dfs.sh
  fi
}

# -------------------------------------
# Order of Commands
# -------------------------------------
# For DataNodes and Client
#    download_hadoop_source
#    set_hadoop_environment
#    set_site_files
# -------------------------------------
# For NameNode
#    generate_cluster_ssh_key (requires manual input)
#    download_hadoop_source
#    set_hadoop_environment
#    set_site_files
#    format_namenode
#    start_dfs

"$@"
