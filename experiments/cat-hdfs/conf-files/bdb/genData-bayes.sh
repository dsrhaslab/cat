#!/bin/bash

#
#The parameter $1 indicates the data size (GB) to generate
#Command for generate data: ./genData-bayes.sh <size> #GB
#

#------------generate-data---------------------
a=$1


cd ../../BigDataGeneratorSuite/Text_datagen/

rm -rf ./gen_data/data-naivebayes
    let L=a*2
    #./gen_text_data.sh amazonMR1 $L 1900 11500 ./gen_data/data-naivebayes/amazonMR1
    #./gen_text_data.sh amazonMR2 $L 1900 11500 ./gen_data/data-naivebayes/amazonMR2
    #./gen_text_data.sh amazonMR3 $L 1900 11500 ./gen_data/data-naivebayes/amazonMR3
    #./gen_text_data.sh amazonMR4 $L 1900 11500 ./gen_data/data-naivebayes/amazonMR4
    #./gen_text_data.sh amazonMR5 $L 1900 11500 ./gen_data/data-naivebayes/amazonMR5
    ./gen_text_data.sh amazonMR1 $L 1900 11500 amazonMR1
    ./gen_text_data.sh amazonMR2 $L 1900 11500 amazonMR2
    ./gen_text_data.sh amazonMR3 $L 1900 11500 amazonMR3
    ./gen_text_data.sh amazonMR4 $L 1900 11500 amazonMR4
    ./gen_text_data.sh amazonMR5 $L 1900 11500 amazonMR5

#-------------------------------------put-data----------------------------#
    #${HADOOP_HOME}/bin/hadoop fs -rmr /hadoop/Bayes/*
    #${HADOOP_HOME}/bin/hadoop fs -mkdir -p /hadoop/Bayes
    #${HADOOP_HOME}/bin/hadoop fs -put ./gen_data/data-naivebayes /hadoop/Bayes/

echo "Hadoop naive bayes end"