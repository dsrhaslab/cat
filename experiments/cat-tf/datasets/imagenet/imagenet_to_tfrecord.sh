#!/bin/sh

export IMAGENET_HOME=$HOME/cat-tf/datasets/imagenet

EXTRACT_DATA=false
RUN_CIA=false

usage() {
      echo "imagenet_to_tfrecord.sh - Extract dataset images and convert to TFRecords"
      echo " "
      echo "./imagenet_to_tfrecord.sh [options] [arguments]"
      echo " "
      echo "options:"
      echo "-h       show brief help"
      echo "-e       extract data from .tar"
      echo "-c     runs imagenet_to_gcs_v2_cia.py instead of imagenet_to_gcs_v2.py"
}

while getopts "hec" opt; do
	case $opt in
		h)
			usage
			exit 0
			;;
            e)
                  EXTRACT_DATA=true
                  ;;
            c)
                  RUN_CIA=true
                  ;;
            *)
			usage
			exit 1
			;;
	esac
done

echo "EXTRACTING DATA FROM .tar? $EXTRACT_DATA"
echo "Running CIA? $RUN_CIA"

if $EXTRACT_DATA ; then

      # Setup folders
      mkdir -p $IMAGENET_HOME/validation
      mkdir -p $IMAGENET_HOME/train

      # Extract validation and training
      tar xf ILSVRC2012_img_val.tar -C $IMAGENET_HOME/validation
      tar xf ILSVRC2012_img_train.tar -C $IMAGENET_HOME/train

      # Extract and then delete individual training tar files This can be pasted
      # directly into a bash command-line or create a file and execute.
      cd $IMAGENET_HOME/train

      for f in *.tar; do
            d=`basename $f .tar`
            mkdir $d
            tar xf $f -C $d
      done

      cd $IMAGENET_HOME # Move back to the base folder

      # [Optional] Delete tar files if desired as they are not needed
      rm $IMAGENET_HOME/train/*.tar

fi

# Process the files. Remember to get the script from github first. The TFRecords
# will end up in the --local_scratch_dir. To upload to gcs with this method
# leave off `nogcs_upload` and provide gcs flags for project and output_path.
if $RUN_CIA; then
      mv $IMAGENET_HOME/train/ $IMAGENET_HOME/old-train/
      mkdir -p $IMAGENET_HOME/train/
      find $IMAGENET_HOME/old-train/n* -maxdepth 1 -type d -print0 | head -z -n 64 | xargs -0 -r -- mv -t $IMAGENET_HOME/train/ --
      python3 imagenet_to_gcs_v2_cia.py \
            --raw_data_dir=$IMAGENET_HOME \
            --local_scratch_dir=$IMAGENET_HOME/tf_records \
            --nogcs_upload

else
      python3 imagenet_to_gcs_v2.py \
            --raw_data_dir=$IMAGENET_HOME \
            --local_scratch_dir=$IMAGENET_HOME/tf_records \
            --nogcs_upload

fi

mv $IMAGENET_HOME/tf_records/train/* $IMAGENET_HOME/tf_records/
mv $IMAGENET_HOME/tf_records/validation/* $IMAGENET_HOME/tf_records/

rm -r $IMAGENET_HOME/tf_records/train $IMAGENET_HOME/tf_records/validation