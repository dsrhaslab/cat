#!/bin/sh

DATASET_HOME=$HOME/cat-tf/datasets/imagenet


FULL_DATASET=true
EXTRACT_DATA=false

usage() {
      echo "imagenet_to_tfrecord.sh - Extract dataset images and convert to TFRecords"
      echo " "
      echo "./imagenet_to_tfrecord.sh [options] [arguments]"
      echo " "
      echo "options:"
      echo "-h       show brief help"
      echo "-s       use imagenet subset (imagenette). Default uses imagenet2012"
      echo "-e       extract data from .tar (to use only with imagenet2012 dataset)"
}

while getopts "hesc" opt; do
	case $opt in
		h)
			usage
			exit 0
			;;
            s)    FULL_DATASET=false
                  ;;
            e)
                  EXTRACT_DATA=true
                  ;;
            *)
			usage
			exit 1
			;;
	esac
done

echo "EXTRACTING DATA FROM .tar? $EXTRACT_DATA"

if $FULL_DATASET ; then
      IMAGENET_HOME="$DATASET_HOME/imagenet2012"
else
      IMAGENET_HOME="$DATASET_HOME/imagenette2"
fi
export IMAGENET_HOME
echo "DATASET_DIR: $IMAGENET_HOME"

if $FULL_DATASET && $EXTRACT_DATA ; then

      # Setup folders
      mkdir -p $IMAGENET_HOME/validation
      mkdir -p $IMAGENET_HOME/train

      # Extract validation and training
      tar xf $IMAGENET_HOME/ILSVRC2012_img_val.tar -C $IMAGENET_HOME/validation
      tar xf $IMAGENET_HOME/ILSVRC2012_img_train.tar -C $IMAGENET_HOME/train

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
cd $DATASET_HOME
python3 imagenet_to_gcs_v2.py \
      --raw_data_dir=$IMAGENET_HOME \
      --local_scratch_dir=$IMAGENET_HOME/tf_records \
      --nogcs_upload

mv $IMAGENET_HOME/tf_records/train/* $IMAGENET_HOME/tf_records/
mv $IMAGENET_HOME/tf_records/validation/* $IMAGENET_HOME/tf_records/

rm -r $IMAGENET_HOME/tf_records/train $IMAGENET_HOME/tf_records/validation