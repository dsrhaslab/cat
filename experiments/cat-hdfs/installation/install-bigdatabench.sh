#!/bin/bash

#########################################################

# Update these variables:
USER="gsd"
BDB_INST_PATH="/home/$USER/bigdatabenchCB"
CAT_HDFS_DIR="/home/$USER/cat-hdfs"

#########################################################

# Clone BigDataBench repository

git clone https://github.com/BenchCouncil/BigDataBench_V5.0_BigData_ComponentBenchmark.git
mv BigDataBench_V5.0_BigData_ComponentBenchmark $BDB_INST_PATH

# Compile Text data generate

cd $BDB_INST_PATH/BigDataGeneratorSuite/Text_datagen
tar -xf gsl-1.15.tar.gz

cp $CAT_HDFS_DIR/conf-files/bdb/gen_random_text.cpp $BDB_INST_PATH/BigDataGeneratorSuite/Text_datagen/
cp $CAT_HDFS_DIR/conf-files/bdb/pgen_random_text.cpp $BDB_INST_PATH/BigDataGeneratorSuite/Text_datagen/
cp $CAT_HDFS_DIR/conf-files/bdb/gen_text_data.sh $BDB_INST_PATH/BigDataGeneratorSuite/Text_datagen/
chmod +x $BDB_INST_PATH/BigDataGeneratorSuite/Text_datagen/gen_text_data.sh

cd $BDB_INST_PATH/BigDataGeneratorSuite/Text_datagen/gsl-1.15
./configure
make
sudo make install
cd $BDB_INST_PATH/BigDataGeneratorSuite/Text_datagen
make

# export mahout

echo "export MAHOUT_HOME=$BDB_INST_PATH/Hadoop/apache-mahout-0.10.2-compile" >> ~/.bashrc
source ~/.bashrc

# copy files
cp $CAT_HDFS_DIR/conf-files/bdb/genData-bayes.sh $BDB_INST_PATH/Hadoop/Bayes/
chmod +x $BDB_INST_PATH/Hadoop/Bayes/genData-bayes.sh
cp $CAT_HDFS_DIR/conf-files/bdb/run-bayes.sh $BDB_INST_PATH/Hadoop/Bayes/
chmod +x $BDB_INST_PATH/Hadoop/Bayes/run-bayes.sh