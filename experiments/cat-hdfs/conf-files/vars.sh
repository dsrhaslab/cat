#!/bin/bash

#########################################################

echo "exporting vars"

CAT_USER=$(whoami)                                              # Username
WORKING_DIR="/mnt/nvme"                                         # Working directory
VOL_LOCAL="$WORKING_DIR/local"                                  # HDFS directory
VOL_DFS="/home/$CAT_USER/dfs"                                   # Hadoop installation directory
HADOOP_VERSION=2.7.1                                            # Hadoop version
N_JAVA_HOME=java-8-openjdk-amd64                                # Java home
CAT_HDFS_DIR="/home/$CAT_USER/cat/experiments/cat-hdfs"         # Path to cat-hdfs dir
CATBPF_BINARY_PATH="/home/$CAT_USER/go/bin"                     # Path to CatBpf binary
BDB_INST_PATH="/home/$CAT_USER/bigdatabenchCB"                  # BigDataBench installation directory

#########################################################

echo "" >> /home/$CAT_USER/.bashrc
echo "#CAT-HDFS VARIABLES START" >> /home/$CAT_USER/.bashrc
echo -e "export CAT_USER=$CAT_USER" >> /home/$CAT_USER/.bashrc
echo -e "export WORKING_DIR=$WORKING_DIR" >> /home/$CAT_USER/.bashrc
echo -e "export VOL_LOCAL=$VOL_LOCAL" >> /home/$CAT_USER/.bashrc
echo -e "export VOL_DFS=$VOL_DFS" >> /home/$CAT_USER/.bashrc
echo -e "export HADOOP_VERSION=$HADOOP_VERSION" >> /home/$CAT_USER/.bashrc
echo -e "export N_JAVA_HOME=$N_JAVA_HOME" >> /home/$CAT_USER/.bashrc
echo -e "export CAT_HDFS_DIR=$CAT_HDFS_DIR" >> /home/$CAT_USER/.bashrc
echo -e "export CATBPF_BINARY_PATH=$CATBPF_BINARY_PATH" >> /home/$CAT_USER/.bashrc
echo -e "export BDB_INST_PATH=$BDB_INST_PATH" >> /home/$CAT_USER/.bashrc
echo -e "export HADOOP_INSTALL=$VOL_DFS/hadoop" >> /home/$CAT_USER/.bashrc
echo "#CAT-HDFS VARIABLES END" >> /home/$CAT_USER/.bashrc
echo "" >> /home/$CAT_USER/.bashrc
source /home/$CAT_USER/.bashrc

#########################################################

echo "Please run the following command: "
echo "source ~/.bashrc"