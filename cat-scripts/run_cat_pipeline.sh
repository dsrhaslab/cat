#!/usr/bin/env bash

GO_PATH="$HOME/go"
CAT_PATH="$HOME/cat"
CUR_DIR=$(pwd)
USER=$(whoami)
HOST=$(hostname)
HOST_IP=$(hostname -i)
GROUP_FLAG="--group-by-host false"

function merge_files {
    CMD="cat"
    echo "Input files:"
    for val in "${input_files[@]}"; do
        echo "  - $val"
        CMD+=" $val"
    done
    CMD+=" > $CUR_DIR/all_catlog.json"
    eval $CMD
}

function sort_files {
    sort $CUR_DIR/all_catlog.json > $CUR_DIR/sorted_catlog.json
}

# $1: path to input_file
function run_falcon_solver {
    echo -e "\n---------------------------"
    echo -e "   Running Falcon-Solver   "
    echo -e "---------------------------"
    java -jar $CAT_PATH/falcon-solver/target/falcon-solver-1.0-SNAPSHOT-jar-with-dependencies.jar  --event-file $CUR_DIR/sorted_catlog.json $GROUP_FLAG --output-file $CUR_DIR/causal_trace.json
}

# $1: path to input_file
function run_casolver_go {
    echo -e "\n-------------------------"
    echo -e "   Running CaSolver-Go   "
    echo -e "-------------------------"
    $GO_PATH/bin/casolver-go --event_file $CUR_DIR/causal_trace.json --output_file $CUR_DIR/similarity_causal_trace.json
}

# $1: path to input_file
function run_casolver_py {
    echo -e "\n-------------------------"
    echo -e "   Running CaSolver-Py   "
    echo -e "-------------------------"
    casolver-py --event_file $CUR_DIR/causal_trace.json --output_file $CUR_DIR/similarity_causal_trace.json
}

function start_falcon_visualizer {
    echo -e "\n------------------------------"
    echo -e "  Starting Falcon-Visualizer  "
    echo -e "------------------------------"
    cd $CAT_PATH/falcon-visualizer/
    nohup npm run dev &>/dev/null &
}

function run_cat_pipeline {


    merge_files
    sort_files
    run_falcon_solver

    if [ "$1" == "catbpf" ]; then
        run_casolver_go "$2"
    else
        run_casolver_py "$2"
    fi

    if ! pgrep -x "node" > /dev/null ; then
        start_falcon_visualizer
    fi

    echo -e "\n------------------------------\n"
    RESULT_FILE_PATH="$CUR_DIR/similarity_causal_trace.json"
    echo -e "Download file: e.g., 'scp <username>@<host_ip>:$RESULT_FILE_PATH .'"
    echo -e "\nAccess Falcon-Visualizer webpage '<host_ip>:8080' and upload the file."

}



# Handle flags
while getopts ":ht:gf:" opt; do
	case $opt in
		h)
			echo "run_cat_pipeline.sh - run CaT pipeline"
			echo " "
			echo "run_cat_pipeline.sh [options] [arguments]"
			echo " "
			echo "options:"
			echo "-h       show brief help"
            echo "-t       CaTracer used to capture the events"
			echo "-f       path to input file"
            echo "-g       group-by-host true"
			exit 0
			;;
		t)
			CATRACER=$OPTARG
			;;
		f)
            input_files+=("$OPTARG")
			BATCH_SIZE=$OPTARG
			;;
        g)
            GROUP_FLAG="--group-by-host true"
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


if [ -z ${CATRACER+x} ]; then
    echo "Please provide the name of the CaTracer used to capture the events (flag -t)."
    exit
fi

if [ ${#input_files[@]} -eq 0 ]; then
    echo "Please provide at least one file to analyze (flag -f)."
    exit
fi

run_cat_pipeline "$CATRACER"






