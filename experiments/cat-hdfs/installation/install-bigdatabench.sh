#!/bin/bash

#########################################################

sudo apt-get install build-essential maven -y


git clone https://github.com/BenchCouncil/BigDataBench_V5.0_BigData_ComponentBenchmark.git
mv BigDataBench_V5.0_BigData_ComponentBenchmark $BDB_INST_PATH
cd $BDB_INST_PATH

sed -i 's/#include <string>/#include <cstring>\n#include <string.h>/gI' $BDB_INST_PATH/BigDataGeneratorSuite/Text_datagen/gen_random_text.cpp
sed -i 's/#include <string>/#include <cstring>\n#include <string.h>/gI' $BDB_INST_PATH/BigDataGeneratorSuite/Text_datagen/pgen_random_text.cpp
cp $CAT_HDFS_DIR/conf-files/bdb/gen_text_data.sh $BDB_INST_PATH/BigDataGeneratorSuite/Text_datagen/
chmod +x $BDB_INST_PATH/BigDataGeneratorSuite/Text_datagen/gen_text_data.sh

# Compile mahout
cd $BDB_INST_PATH/Hadoop/apache-mahout-0.10.2-compile/
sed -i 's/<version>\[1.7, 1.8)<\/version>/<version>\[1.7, 1.9)<\/version>/' pom.xml
sed -i 's/<version>\[1.7, 1.8)<\/version>/<version>\[1.7, 1.9)<\/version>/' buildtools/pom.xml
mvn clean install -DskipTests

echo "export LD_RUN_PATH=/usr/local/lib:$LD_RUN_PATH"  >> /home/$CAT_USER/.bashrc
export LD_RUN_PATH=/usr/local/lib:$LD_RUN_PATH
echo "export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH" >> /home/$CAT_USER/.bashrc
export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH
echo "export MAHOUT_HOME=$BDB_INST_PATH/Hadoop/apache-mahout-0.10.2-compile" >> /home/$CAT_USER/.bashrc
export MAHOUT_HOME=$BDB_INST_PATH/Hadoop/apache-mahout-0.10.2-compile
echo "Run 'source /home/$CAT_USER/.bashrc'"

# Compile gsl
cd $BDB_INST_PATH/BigDataGeneratorSuite/Text_datagen
tar -xf gsl-1.15.tar.gz
cd $BDB_INST_PATH/BigDataGeneratorSuite/Text_datagen/gsl-1.15
./configure
make clean
make
sudo make install
ldconfig -n /usr/local/lib

# Compile Text data generate
cd $BDB_INST_PATH/BigDataGeneratorSuite/Text_datagen
make clean
make

# Copy files
cp $CAT_HDFS_DIR/conf-files/bdb/genData-bayes.sh $BDB_INST_PATH/Hadoop/Bayes/
chmod +x $BDB_INST_PATH/Hadoop/Bayes/genData-bayes.sh
cp $CAT_HDFS_DIR/conf-files/bdb/run-bayes.sh $BDB_INST_PATH/Hadoop/Bayes/
chmod +x $BDB_INST_PATH/Hadoop/Bayes/run-bayes.sh