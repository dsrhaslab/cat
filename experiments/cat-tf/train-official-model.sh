#!/bin/bash

# Change these variables
# ======================================================================================
CAT_TF_DIR="$HOME/cat-tf"
SCRIPT_DIR="$CAT_TF_DIR/official-models-2.1.0/official/vision/image_classification"
VENV_DIR="$CAT_TF_DIR/tf-venv"
RESOURCES_DIR="$CAT_TF_DIR/resources"
RESULTS_DIR="$CAT_TF_DIR/results"
LOCAL_DATASET_DIR="$CAT_TF_DIR/datasets/imagenet/tf_records/"
CHECKPOINTING_DIR="/tmp/checkpointing"
# ======================================================================================

# Default values
MODEL="lenet"
BATCH_SIZE=64
EPOCHS=10
NUM_GPUS=1
DEPLOYMENT=vanilla

# Current date
DATE="$(date +%Y_%m_%d-%H_%M)"

# Functions
function export-vars {
	export PYTHONPATH=$PYTHONPATH:$CAT_TF_DIR/official-models-2.1.0
	export TF_FORCE_GPU_ALLOW_GROWTH=true
}

function create-venv {
	echo "Creating python enviroment"
	echo "rm -rf $VENV_DIR"
	rm -rf $VENV_DIR

	echo "Creating python env"

	echo "python3 -m venv $VENV_DIR"
	python3 -m venv $VENV_DIR

	echo "source env1/bin/activate"
	source $VENV_DIR/bin/activate

	pip3 install --upgrade pip

	echo "pip3 install six numpy wheel setuptools moc"
	pip3 install six numpy wheel setuptools moc

	echo "pip3 install  future>=0.17.1"
	pip3 install  'future>=0.17.1'

	echo "pip3 install keras_applications --no-deps"
	pip3 install keras_applications --no-deps

	echo "pip3 install keras_preprocessing --no-deps"
	pip3 install keras_preprocessing --no-deps

	echo "pip3 install tensorflow"
	pip3 install tensorflow

	echo "pip3 install tensorflow_datasets (needed to run the example)"
	pip3 install tensorflow_datasets

	echo "pip3 install tensorflow_model_optimization (needed to run the example)"
	pip3 install tensorflow_model_optimization


}


function clean {
	# Clean cache
	free -m
	sudo sh -c "sync; echo 3 > /proc/sys/vm/drop_caches"
	sudo sh -c "swapoff -a && swapon -a"
	free -m
}

function monitor {
	dstat --time --cpu --mem --net --disk --swap -D nvme0n1 --output $RUN_DIR/dstat-$DATE.csv > /dev/null &
	sh $RESOURCES_DIR/iostat-csv/iostat-csv.sh > $RUN_DIR/iostat-$DATE.csv &
	nvidia-smi --query-gpu=utilization.gpu,utilization.memory,memory.total,memory.free,memory.used --format=csv -l 1 -f $RUN_DIR/nvidia-smi-$DATE.csv &
}



function select-train-model {
	if [ "$MODEL" == "resnet" ]
	then
		echo -e "Model: ResNet-50\nDataset: ImageNet\nBatch size: $BATCH_SIZE\n#Epochs: $EPOCHS\nShuffle Buffer: $SHUFFLE_BUFFER\nGPUs: $NUM_GPUS\nFramework: Tensorflow" > $RUN_DIR/info-$RUN_NAME.txt
		MODEL_SCRIPT=resnet_imagenet_main.py
	elif [ "$MODEL" == "alexnet" ]
	then
		echo -e "Model: AlexNet\nDataset: ImageNet\nBatch size: $BATCH_SIZE\n#Epochs: $EPOCHS\nShuffle Buffer: $SHUFFLE_BUFFER\nGPUs: $NUM_GPUS\nFramework: Tensorflow" > $RUN_DIR/info-$RUN_NAME.txt
		MODEL_SCRIPT=alexnet_imagenet_main.py
	elif [ "$MODEL" == "lenet" ]
	then
		echo -e "Model: LeNet\nDataset: ImageNet\nBatch size: $BATCH_SIZE\n#Epochs: $EPOCHS\nShuffle Buffer: $SHUFFLE_BUFFER\nGPUs: $NUM_GPUS\nFramework: Tensorflow" > $RUN_DIR/info-$RUN_NAME.txt
		if $RUN_CIA ; then
			MODEL_SCRIPT=lenet_imagenet_main_cia.py
			echo -e "CIA: true" >> $RUN_DIR/info-$RUN_NAME.txt
		else
			MODEL_SCRIPT=lenet_imagenet_main.py
		fi
	else
		echo "Select a valid model. Run train-model -h to see the available models"
	fi
}

function select-deployment {
	if $RUN_CIA && $SHUFFLE == false ; then
		SHUFFLE_FLAG="--shuffle false"
		echo -e "Shuffle: Off" >> $RUN_DIR/info-$RUN_NAME.txt
	elif $RUN_CIA && ${SHUFFLE} ; then
		SHUFFLE_FLAG="--shuffle true"
		echo -e "Shuffle: On" >> $RUN_DIR/info-$RUN_NAME.txt
	else
		SHUFFLE_FLAG=""
	fi
	UNBUFFER_PATH=$(which unbuffer)
	if [ "$DEPLOYMENT" == "vanilla" ]
	then
		echo -e "Deployment: Vanilla" >> $RUN_DIR/info-$RUN_NAME.txt
		$UNBUFFER_PATH -p $VENV_DIR/bin/python3 $SCRIPT_DIR/$MODEL_SCRIPT $SHUFFLE_FLAG --train_epochs=$EPOCHS --batch_size=$BATCH_SIZE --model_dir=$CHECKPOINTING_DIR --data_dir=$LOCAL_DATASET_DIR --num_gpus=$NUM_GPUS | tee $RUN_DIR/log-$RUN_NAME.txt
	elif [ "$DEPLOYMENT" == "catbpf" ]
	then
		echo -e "Deployment: CatBpf" >> $RUN_DIR/info-$RUN_NAME.txt
		sudo -E env PYTHONPATH=$PYTHONPATH $HOME/go/bin/catbpf --stats --whitelist whitelist.txt -log2file -c 4 $UNBUFFER_PATH -p $VENV_DIR/bin/python3 $SCRIPT_DIR/$MODEL_SCRIPT $SHUFFLE_FLAG --train_epochs=$EPOCHS --batch_size=$BATCH_SIZE --model_dir=$CHECKPOINTING_DIR --data_dir=$LOCAL_DATASET_DIR --num_gpus=$NUM_GPUS | tee $RUN_DIR/log-$RUN_NAME.txt
		mv CATlog.json $RUN_DIR/trace-$RUN_NAME.json
		mv catbpf.log $RUN_DIR/catbpf-log-$RUN_NAME.txt
	elif [ "$DEPLOYMENT" == "catstrace" ]
	then
		echo -e "Deployment: CatStrace" >> $RUN_DIR/info-$RUN_NAME.txt

		echo -e "Running strace..."
		sudo -E env PYTHONPATH=$PYTHONPATH strace -o $RUN_DIR/strace.out -e trace=open,openat,read,pread64,write,pwrite64,accept,accept4,connect,socket,recv,recvfrom,recvmsg,send,sendto,sendmsg -tt -yy -f -s 262144  $UNBUFFER_PATH -p $VENV_DIR/bin/python3 $SCRIPT_DIR/$MODEL_SCRIPT $SHUFFLE_FLAG --train_epochs=$EPOCHS --batch_size=$BATCH_SIZE --model_dir=$CHECKPOINTING_DIR --data_dir=$LOCAL_DATASET_DIR --num_gpus=$NUM_GPUS | tee $RUN_DIR/log-$RUN_NAME.txt

		read -p "Parse strace output with catstrace? (Y/N): " confirm
		if [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]] ; then
			# run catstrace
			echo -e "Running CatStrace (parsing strace output)"
			sudo -E env PYTHONPATH=$PYTHONPATH catstrace --stats --whitelist whitelist.txt --input $RUN_DIR/strace.out
			mv CATlog.json $RUN_DIR/trace-$RUN_NAME.json
			mv CatStrace-stats.json $RUN_DIR/catstrace-stats-$RUN_NAME.txt
			mv catstrace.log $RUN_DIR/catstrace-log-$RUN_NAME.txt
		fi

	else
		echo "Select a valid deployment. Run train-model -h to see the available deployments"
	fi
}

function kill-monitor {
	echo -e "\nKilling jobs: \n$(jobs -p)"
	sudo kill $(jobs -p)
	echo -e $(pgrep iostat)
	sudo kill $(pgrep iostat)
}


# Create virtual environment
create-venv
# source $VENV_DIR/bin/activate

# Update env vars
export-vars

# Handle flags
echo -e "\nHandling flags..."
while getopts ":hm:b:e:s:g:d:c:x:" opt; do
	case $opt in
		h)
			echo "$package - train Tensorflow models on ImageNet dataset"
			echo " "
			echo "$package [options] application [arguments]"
			echo " "
			echo "options:"
			echo "-h       show brief help"
			echo "-m       specify the model to train (lenet, resnet or alexnet)"
			echo "-b       specify batch size"
			echo "-e       specify number of epochs"
			echo "-g       specify number of GPUs"
			echo "-d       specify the deployment (vanilla, catbpf, catstrace)"
			echo "-c       run cia version"
			echo "-x       shuffle files"
			exit 0
			;;
		m)
			echo "-m was triggered, Parameter: $OPTARG" >&2
			MODEL=$OPTARG
			;;
		b)
			echo "-b was triggered, Parameter: $OPTARG" >&2
			BATCH_SIZE=$OPTARG
			;;
		e)
			echo "-e was triggered, Parameter: $OPTARG" >&2
			EPOCHS=$OPTARG
			;;
		g)
			echo "-g was triggered, Parameter: $OPTARG" >&2
			NUM_GPUS=$OPTARG
			;;
		d)
			echo "-d was triggered, Parameter: $OPTARG" >&2
			DEPLOYMENT=$OPTARG
			;;
		c)
			echo "-c was triggered, Parameter: $OPTARG" >&2
			RUN_CIA=$OPTARG
			;;
		x)
			echo "-x was triggered, Parameter: $OPTARG" >&2
			SHUFFLE=$OPTARG
			;;
		\?)
			echo "Invalid option: -$OPTARG" >&2
			exit 1
			;;
		:)
			echo "Option -$OPTARG requires an argument." >&2
			exit 1
			;;
	esac
done

# Create results directory
RUN_NAME="$MODEL-bs$BATCH_SIZE-ep$EPOCHS-$DEPLOYMENT-$DATE"
RUN_DIR="$RESULTS_DIR/$RUN_NAME"
mkdir -p $RUN_DIR

# Clean cache
clean

# Create log file
touch $RUN_DIR/log-$RUN_NAME.txt

# Start monitoring tools
trap 'kill 0' SIGINT # trap to kill all bg processes when pressing CTRL-C
monitor
sleep 10

# Start training the model
SECONDS=0

select-train-model
select-deployment

echo "ELAPSED TIME: $SECONDS s" | tee -a $RUN_DIR/log-$RUN_NAME.txt
sleep 10

# Kill monitor process
kill-monitor

