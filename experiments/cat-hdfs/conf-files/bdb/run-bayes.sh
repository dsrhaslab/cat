#!/bin/bash

# Run command: ./run-bayes.sh

#--------------------------------------run-workload-----------------------#
#Generates input dataset for training & testing classifier
dir=/hadoop/Bayes
echo "Creating sequence files from naivebayes-naivebayes data"
 ${MAHOUT_HOME}/bin/mahout seqdirectory \
  -i /hadoop/Bayes/data-naivebayes \
  -o /hadoop/Bayes/naivebayes-seq -ow

echo "Converting sequence files to vectors"
 ${MAHOUT_HOME}/bin/mahout seq2sparse \
  -i /hadoop/Bayes/naivebayes-seq \
  -o /hadoop/Bayes/naivebayes-vectors  -lnorm -nv  -wt tfidf

echo "Creating training and holdout set with a random 80-20 split of the generated vector dataset"
 ${MAHOUT_HOME}/bin/mahout split \
  -i /hadoop/Bayes/naivebayes-vectors/tfidf-vectors \
  --trainingOutput /hadoop/Bayes/naivebayes-train-vectors \
  --testOutput /hadoop/Bayes/naivebayes-test-vectors  \
  --randomSelectionPct 70 --overwrite --sequenceFiles -xm sequential
#Trains the classifier
echo "Training Naive Bayes model"
 ${MAHOUT_HOME}/bin/mahout trainnb \
  -i /hadoop/Bayes/naivebayes-train-vectors  \
  -o /hadoop/Bayes/model \
  -li /hadoop/Bayes/labelindex \
  -ow #$c
#------------------------------------------run------------------------------#

${HADOOP_INSTALL}/bin/hdfs dfs -rm -r /hadoop/Bayes/naivebayes-testing
${MAHOUT_HOME}/bin/mahout testnb \
 -i /hadoop/Bayes/naivebayes-test-vectors \
 -m /hadoop/Bayes/model \
 -l /hadoop/Bayes/labelindex \
 -ow -o /hadoop/Bayes/naivebayes-testing #$c


echo "Hadoop naive bayes end"