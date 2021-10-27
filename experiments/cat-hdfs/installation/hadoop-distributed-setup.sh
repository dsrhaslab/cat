#!/bin/bash

#########################################################

HOST=$(hostname)
CONF_DIR="$CAT_HDFS_DIR/conf-files"

HADOOP_TMP_DIR="$VOL_DFS/app/hadoop/tmp"
HADOOP_NAMENODE_DIR="$VOL_LOCAL/hadoop_store/hdfs/namenode"
HADOOP_DATANODE_DIR="$VOL_LOCAL/hadoop_store/hdfs/datanode"

declare -a hosts
readarray -t hosts < "$CONF_DIR/hosts"
MASTER_ROW=(${hosts[0]})
MASTER="${MASTER_ROW[0]}"
MASTER_IP="${MASTER_ROW[1]}"

#########################################################

function generate_cluster_ssh_key {
  mkdir -p /home/$CAT_USER/.ssh/
  cd /home/$CAT_USER/.ssh/
  # generate a passwordless ssh-key
  ssh-keygen -t rsa -P "" -f id_rsa
  # copy ssh-key to the authorized keys
  cat /home/$CAT_USER/.ssh/id_rsa.pub >> /home/$CAT_USER/.ssh/authorized_keys
  chmod 600 authorized_keys
  cd /home/$CAT_USER/

  # Copy the public key to each slave
  hlen=${#hosts[@]}
  # Send to all hosts minus the master
  for (( i=0; i<${hlen}; i++ )); do
    host_row=(${hosts[$i]})
    echo "Host: ${host_row[0]}"
    ssh-copy-id -i /home/$CAT_USER/.ssh/id_rsa.pub $CAT_USER@${host_row[1]}
  done
}

function download_hadoop_source {
  # Donwload from sources
  cd /home/$CAT_USER/
  wget https://archive.apache.org/dist/hadoop/core/hadoop-$HADOOP_VERSION/hadoop-$HADOOP_VERSION.tar.gz
  tar xvzf hadoop-$HADOOP_VERSION.tar.gz
  mkdir -p $HADOOP_INSTALL
  mv hadoop-$HADOOP_VERSION/* $HADOOP_INSTALL
  rmdir hadoop-$HADOOP_VERSION
  rm hadoop-$HADOOP_VERSION.tar.gz
  # Create required directories
  mkdir -p $HADOOP_TMP_DIR
  mkdir -p $HADOOP_NAMENODE_DIR
  mkdir -p $HADOOP_DATANODE_DIR
}

function set_hadoop_environment {
  # Add Haddop variables to .bashrc file (of $CAT_USER)
  echo "" >> /home/$CAT_USER/.bashrc
  echo "#HADOOP VARIABLES START" >> /home/$CAT_USER/.bashrc
  echo "export JAVA_HOME=/usr/lib/jvm/$N_JAVA_HOME" >> /home/$CAT_USER/.bashrc
  echo "export HADOOP_INSTALL=$HADOOP_INSTALL" >> /home/$CAT_USER/.bashrc
  echo "export HADOOP_HOME=$HADOOP_INSTALL" >> /home/$CAT_USER/.bashrc
  echo "export PATH=\$PATH:\$HADOOP_INSTALL/bin" >> /home/$CAT_USER/.bashrc
  echo "export PATH=\$PATH:\$HADOOP_INSTALL/sbin" >> /home/$CAT_USER/.bashrc
  echo "export HADOOP_MAPRED_HOME=\$HADOOP_INSTALL" >> /home/$CAT_USER/.bashrc
  echo "export HADOOP_COMMON_HOME=\$HADOOP_INSTALL" >> /home/$CAT_USER/.bashrc
  echo "export HADOOP_HDFS_HOME=\$HADOOP_INSTALL" >> /home/$CAT_USER/.bashrc
  echo "export YARN_HOME=\$HADOOP_INSTALL" >> /home/$CAT_USER/.bashrc
  echo "export HADOOP_COMMON_LIB_NATIVE_DIR=\$HADOOP_INSTALL/lib/native" >> /home/$CAT_USER/.bashrc
  echo "export HADOOP_OPTS=\"-Djava.library.path=\$HADOOP_INSTALL/lib\"" >> /home/$CAT_USER/.bashrc
  echo "#HADOOP VARIABLES END" >> /home/$CAT_USER/.bashrc
  source /home/$CAT_USER/.bashrc

  sed -i.bak "s@.*export JAVA_HOME=.*@export JAVA_HOME=\/usr\/lib\/jvm\/$N_JAVA_HOME/@g" $HADOOP_INSTALL/etc/hadoop/hadoop-env.sh
  echo "set-hadoop-environment: check if the changes were commited to the .bashrc file. If not, source it."
}


function set_site_files {
  general_files=("core" "hdfs" "yarn")
  for file in "${general_files[@]}"; do
    echo "File: = $file-site"
    mv $HADOOP_INSTALL/etc/hadoop/$file-site.xml $HADOOP_INSTALL/etc/hadoop/$file-site.xml.bak
    cp $CONF_DIR/site/$file-site.xml $HADOOP_INSTALL/etc/hadoop/$file-site.xml
  done

  # This command will be only applied in the core-site.xml file. It will define the host of the HDFS-Master and
  # the path for the tmp directory (that will store the temporary files of HDFS such as MapReduce tasks)
  if [ "$HADOOP_VERSION" == "hadoop-2.9.2" ]; then
    sed -i "s#master:#$MASTER_IP:9000#g" "$HADOOP_INSTALL/etc/hadoop/core-site.xml"
  else
    sed -i "s#master:#$MASTER_IP:54310#g" "$HADOOP_INSTALL/etc/hadoop/core-site.xml"
  fi
  sed -i "s#<value>hadoop-tmp-dir</value>#<value>$HADOOP_TMP_DIR</value>#g" "$HADOOP_INSTALL/etc/hadoop/core-site.xml"

  # This command will be only applied in the hdfs-site.xml file. It will define the replication factor and the
  # path for both NameNode and DataNode directories.
  sed -i "s#<value>1</value>#<value>3</value>#g" "$HADOOP_INSTALL/etc/hadoop/hdfs-site.xml"
  sed -i "s#<value>hdfs-namenode-dir</value>#<value>file:$HADOOP_NAMENODE_DIR</value>#g" "$HADOOP_INSTALL/etc/hadoop/hdfs-site.xml"
  sed -i "s#<value>hdfs-datanode-dir</value>#<value>file:$HADOOP_DATANODE_DIR</value>#g" "$HADOOP_INSTALL/etc/hadoop/hdfs-site.xml"

  # This command will be only applied in the yarn-site.xml file
  sed -i "s#master:8030#$MASTER_IP:8030#g" "$HADOOP_INSTALL/etc/hadoop/yarn-site.xml"
  sed -i "s#master:8032#$MASTER_IP:8032#g" "$HADOOP_INSTALL/etc/hadoop/yarn-site.xml"
  sed -i "s#master:8088#$MASTER_IP:8088#g" "$HADOOP_INSTALL/etc/hadoop/yarn-site.xml"
  sed -i "s#master:8031#$MASTER_IP:8031#g" "$HADOOP_INSTALL/etc/hadoop/yarn-site.xml"
  sed -i "s#master:8033#$MASTER_IP:8033#g" "$HADOOP_INSTALL/etc/hadoop/yarn-site.xml"


  sed -i "s@HADOOP\_PORTMAP\_OPTS=\"-Xmx512m \$HADOOP\_PORTMAP\_OPTS\"@HADOOP_PORTMAP_OPTS=\"-Xmx2048m \$HADOOP\_PORTMAP\_OPTS\"@g" $HADOOP_INSTALL/etc/hadoop/hadoop-env.sh
  sed -i "s@HADOOP\_CLIENT\_OPTS=\"-Xmx512m \$HADOOP\_CLIENT\_OPTS\"@HADOOP\_CLIENT\_OPTS=\"-Xmx2048m \$HADOOP\_CLIENT\_OPTS\"@g" $HADOOP_INSTALL/etc/hadoop/hadoop-env.sh

  # master_files=("mapred" "workers")
  if [ "$HOST" = "$MASTER" ]; then
    # Move mapred-site.xml file
    mv $HADOOP_INSTALL/etc/hadoop/mapred-site.xml $HADOOP_INSTALL/etc/hadoop/mapred-site.xml.bak
    cp $CONF_DIR/site/mapred-site.xml $HADOOP_INSTALL/etc/hadoop/mapred-site.xml
    # This command will be only applied in the mapred-site.xml
    sed -i "s#master:54311#$MASTER_IP:54311#g" "$HADOOP_INSTALL/etc/hadoop/mapred-site.xml"

    workersfile=slaves

    # Move workers file
    mv $HADOOP_INSTALL/etc/hadoop/$workersfile $HADOOP_INSTALL/etc/hadoop/$workersfile.bak
    touch $HADOOP_INSTALL/etc/hadoop/$workersfile
    echo "# NameNodes" >> $HADOOP_INSTALL/etc/hadoop/$workersfile

    hlen=${#hosts[@]}
    # Print the datanode id of each slave to the workers file
    for (( i=1; i<${hlen}; i++ )); do
    host_row=(${hosts[$i]})
      echo "datanode-$i: ${host_row[1]}"
      echo "${host_row[1]}" >> $HADOOP_INSTALL/etc/hadoop/$workersfile
    done
  fi

}

function format_namenode {
    if [ "$HOST" = "$MASTER" ]; then
      $HADOOP_INSTALL/sbin/stop-dfs.sh
      rm -rf $HADOOP_TMP_DIR/*
      echo "y" | hdfs namenode -format
    fi
}

function format_datanode {
  $HADOOP_INSTALL/sbin/stop-dfs.sh
  rm -Rf $VOL_LOCAL/hadoop_store/hdfs/datanode/*
}

function start_dfs {
  if [ "$HOST" = "$MASTER" ]; then
    $HADOOP_INSTALL/sbin/start-dfs.sh
  fi
}


function install_client {
  generate_cluster_ssh_key
  download_hadoop_source
  set_hadoop_environment
  set_site_files
}

function install_datanode {
  download_hadoop_source
  set_hadoop_environment
  set_site_files
}

function install_namenode {
  generate_cluster_ssh_key
  download_hadoop_source
  set_hadoop_environment
  set_site_files
  format_namenode
  start_dfs
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
