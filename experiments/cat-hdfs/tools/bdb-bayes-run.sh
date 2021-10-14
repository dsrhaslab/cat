#!/bin/bash


#########################################################

# Update these variables:

USER="gsd"
WORKING_DIR="/mnt/nvme"
CATBPF_BINARY_PATH="/home/$USER/go/bin"
VOL_LOCAL="$WORKING_DIR/local"
VOL_DFS="/home/$USER/dfs"
BDB_INST_PATH="/home/$USER/bigdatabenchCB"
RESULTS_PATH="$WORKING_DIR/bdb-bayes-results"
CAT_HDFS_DIR="/home/$USER/cat-hdfs"


#########################################################

CONF_DIR="$CAT_HDFS_DIR/conf-files"
BDB_PATH="$BDB_INST_PATH/Hadoop/Bayes"

declare -a hosts
readarray -t hosts < "$CONF_DIR/hosts"
MASTER_ROW=(${hosts[0]})
MASTER="${MASTER_ROW[0]}"
MASTER_IP="${MASTER_ROW[1]}"
HADOOP_PATH="$VOL_DFS/hadoop"


HOST=$(hostname)
HOST_IP=$(hostname -i)

# cool_down_time_load=1680s
cool_down_time_load=5s


# Logging message
LOG="--- bdb-bayes-run.sh >>"


function clean_up_hdfs {
    echo "$LOG clean_up_hdfs"

    # stop hdfs
    $CAT_HDFS_DIR/tools/hdfs-clean-up.sh stop_hdfs
    $CAT_HDFS_DIR/tools/hdfs-clean-up.sh clean_cache
    $CAT_HDFS_DIR/tools/hdfs-clean-up.sh clean_tmp_files
    $CAT_HDFS_DIR/tools/hdfs-clean-up.sh clean_logs
    $CAT_HDFS_DIR/tools/hdfs-clean-up.sh clean_datanodes

    # format file system
    for (( i=0; i<${#hosts[@]}; i++ )); do
        host_row=(${hosts[$i]})
        ssh $USER@${host_row[1]} "rm -rf $VOL_LOCAL/*"
    done

    # format hdfs-namenode
    ssh $USER@$MASTER 'echo "y" | '$HADOOP_PATH'/bin/hdfs namenode -format'
}

# Launch dstat in each node
# $1 = mode (genData | run)
# $2 = size (in GB)
# $3 = run
function dstat_launch {
    echo "$LOG dstat-launch: $1:$2:$3"

    echo "$LOG dstat-launch: Launching dstats..."
    DSTAT_PIDS=()

    namenode=(${hosts[0]})
    dstat_pid=$(ssh $USER@${namenode[1]} "dstat --time --cpu --mem --net --disk --swap --output /home/$USER/dstat-$1-$2G-namenode-$3.csv &>/dev/null & echo \$!")
    DSTAT_PIDS+=("${namenode[1]} $dstat_pid")

    for (( i=1; i<${#hosts[@]}; i++ )); do
        host_row=(${hosts[$i]})
        dstat_pid=$(ssh $USER@${host_row[1]} "dstat --time --cpu --mem --net --disk --swap --output /home/$USER/dstat-$1-$2G-datanode$i-$3.csv &>/dev/null & echo \$!")
        DSTAT_PIDS+=("${host_row[1]} $dstat_pid")
    done

    echo -n "$LOG dstat-launch: Dstat instances: "
    for a in "${DSTAT_PIDS[@]}"; do stringarray=($a); echo -n "${stringarray[1]} (${stringarray[0]}); "; done
    echo ""

    screen -S BDB_DSTAT -d -m ssh $HOST_IP "dstat --time --cpu --mem --net --disk --swap --output /home/$USER/dstat-$1-$2G-client-$3.csv"
}

# Stop dstat in each node
# $1 = mode (genData | run)
# $2 = size (in GB)
# $3 = run
function dstat_stop {
    echo "$LOG dstat-stop: $1:$2:$3"

    # stop client dstat and copy data to $RESULTS_PATH
    screen -X -S BDB_DSTAT quit
    mkdir -p $RESULTS_PATH/$2G/
    mv /home/$USER/dstat-$1-$2G-client-$3.csv $RESULTS_PATH/$2G/dstat-$1-$2G-client-$3.csv

    DSTAT_PIDS_TO_STOP=( "${DSTAT_PIDS[@]}" )
    echo -n "$LOG dstat-stop:  killing dstat instances: "
    for a in "${DSTAT_PIDS_TO_STOP[@]}"; do stringarray=($a); echo -n "${stringarray[1]} (${stringarray[0]}); "; done
    echo ""

    # stop namenode and datanodes dstats
    for val in "${DSTAT_PIDS_TO_STOP[@]}" ; do
        stringarray=($val)
        ip="${stringarray[0]}"
        dstat_pid="${stringarray[1]}"
        ssh $USER@$ip "sudo kill -9 $dstat_pid"
    done
    sleep 10

    # copy data to $RESULTS_PATH for namenode
    namenode=(${hosts[0]})
    ssh $USER@${namenode[1]} "mv /home/$USER/dstat-$1-$2G-namenode-$3.csv $RESULTS_PATH/$2G/dstat-$1-$2G-namenode-$3.csv"

    # copy data to $RESULTS_PATH for datanodes
    for (( i=1; i<${#hosts[@]}; i++ )); do
        host_row=(${hosts[$i]})
        ssh $USER@${host_row[1]} "mv /home/$USER/dstat-$1-$2G-datanode$i-$3.csv $RESULTS_PATH/$2G/dstat-$1-$2G-datanode$i-$3.csv"
    done
}

# Launch catbpf in each node
# $1 = mode (genData | run)
# $2 = size (in GB)
# $3 = run
function catbpf_launch {
    echo "$LOG catbpf-launch: $1:$2:$3"
    NODES_PIDS=()
    CATBPF_PIDS=()

    # Get Namenode and datanodes pids
    namenode=(${hosts[0]})
    namenode_pid=$(ssh $USER@${namenode[1]} 'jps | grep " NameNode" | cut -d" " -f1 | xargs --no-run-if-empty -I@ bash -c "echo @"')
    NODES_PIDS+=("${namenode[1]} $namenode_pid")
    for (( i=1; i<${#hosts[@]}; i++ )); do
        host_row=(${hosts[$i]})
        datanode_pid=$(ssh $USER@${host_row[1]} 'jps | grep " DataNode" | cut -d" " -f1 | xargs --no-run-if-empty -I@ bash -c "echo @"')
        NODES_PIDS+=("${host_row[1]} $datanode_pid")
    done
    echo -n "$LOG catbpf-launch:  Nodes are: "
    for a in "${NODES_PIDS[@]}"; do stringarray=($a); echo -n "${stringarray[1]} (${stringarray[0]}); "; done
    echo ""

    # launch catbpf instances
    for val in "${NODES_PIDS[@]}" ; do
        stringarray=($val)
        ip="${stringarray[0]}"
        node_pid="${stringarray[1]}"
        catbpf_pid=$(ssh $USER@${ip} "sudo -E $CATBPF_BINARY_PATH/catbpf --stats --whitelist $CONF_DIR/whitelist-bdb.txt --log2file -c 4 --pid $node_pid &>/dev/null & echo \$!")
        CATBPF_PIDS+=("${ip} $catbpf_pid")
    done
    echo -n "$LOG catbpf-launch:  CatBpf instances: "
    for a in "${CATBPF_PIDS[@]}"; do stringarray=($a); echo -n "${stringarray[1]} (${stringarray[0]}); "; done
    echo ""
    sleep 10s
}

# Stop catbpf in each node
# $1 = mode (genData | run)
# $2 = size (in GB)
# $3 = run
function catbpf_stop {
    echo "$LOG catbpf-stop: $1:$2:$3"

    CATBPF_PIDS_TO_STOP=( "${CATBPF_PIDS[@]}" )
    echo -n "$LOG catbpf-stop:  Killing CatBpf instances: "
    for a in "${CATBPF_PIDS_TO_STOP[@]}"; do stringarray=($a); echo -n "${stringarray[1]} (${stringarray[0]}); "; done
    echo ""

    # stop catbpf instances
    for val in "${CATBPF_PIDS_TO_STOP[@]}" ; do
        stringarray=($val)
        ip="${stringarray[0]}"
        node_pid="${stringarray[1]}"
        ssh $USER@${ip} "sudo kill -s SIGINT $node_pid"
    done

    echo "$LOG catbpf-stop:  Waiting for CatBpf instances to finish..."
    for val in "${CATBPF_PIDS_TO_STOP[@]}" ; do
        stringarray=($val)
        ip="${stringarray[0]}"
        node_pid="${stringarray[1]}"
        ssh $USER@${ip} "while ps -p $node_pid >/dev/null 2>&1; do sleep 10; done"
    done

    # copy data to $RESULTS_PATH for namenode
    namenode=(${hosts[0]})
    ssh $USER@${namenode[1]} "mv /home/$USER/catbpf.log $RESULTS_PATH/$2G/catbpf-$1-$2G-namenode-$3.txt;"
    ssh $USER@${namenode[1]} "mv /home/$USER/CATlog.json $RESULTS_PATH/$2G/trace-$1-$2G-namenode-$3.json"

    # copy data to $RESULTS_PATH for datanodes
    for (( i=1; i<${#hosts[@]}; i++ )); do
        host_row=(${hosts[$i]})
        ssh $USER@${host_row[1]} "mv /home/$USER/catbpf.log $RESULTS_PATH/$2G/catbpf-$1-$2G-datanode$i-$3.txt;"
        ssh $USER@${host_row[1]} "mv /home/$USER/CATlog.json $RESULTS_PATH/$2G/trace-$1-$2G-datanode$i-$3.json;"
    done

    # copy data to $RESULTS_PATH for client
    mv CATlog.json $RESULTS_PATH/$2G/trace-$1-$2G-client-$3.json
    mv catbpf.log $RESULTS_PATH/$2G/catbpf-$1-$2G-client-$3.txt
}

# Launch strace in each node
# $1 = mode (genData | run)
# $2 = size (in GB)
# $3 = run
function strace_launch {
    echo "$LOG strace-launch: $1:$2:$3"
    NODES_PIDS=()
    STRACE_PIDS=()

    # Get Namenode and datanodes pids
    namenode=(${hosts[0]})
    namenode_pid=$(ssh $USER@${namenode[1]} 'jps | grep " NameNode" | cut -d" " -f1 | xargs --no-run-if-empty -I@ bash -c "echo @"')
    NODES_PIDS+=("${namenode[1]} $namenode_pid")
    for (( i=1; i<${#hosts[@]}; i++ )); do
        host_row=(${hosts[$i]})
        datanode_pid=$(ssh $USER@${host_row[1]} 'jps | grep " DataNode" | cut -d" " -f1 | xargs --no-run-if-empty -I@ bash -c "echo @"')
        NODES_PIDS+=("${host_row[1]} $datanode_pid")
    done
    echo -n "$LOG strace-launch:  Nodes are: "
    for a in "${NODES_PIDS[@]}"; do stringarray=($a); echo -n "${stringarray[1]} (${stringarray[0]}); "; done
    echo ""

    # launch strace instances
    for val in "${NODES_PIDS[@]}" ; do
        stringarray=($val)
        ip="${stringarray[0]}"
        node_pid="${stringarray[1]}"
        strace_pid=$(ssh $USER@${ip} "sudo -E strace -o /home/$USER/strace.out -e trace=open,openat,read,pread64,write,pwrite64,accept,accept4,connect,socket,recv,recvfrom,recvmsg,send,sendto,sendmsg -s 262144 -tt -yy -f -p $node_pid &>/dev/null & echo \$!")
        STRACE_PIDS+=("${ip} $strace_pid")
    done
    echo -n "$LOG strace-launch:  Strace instances: "
    for a in "${STRACE_PIDS[@]}"; do stringarray=($a); echo -n "${stringarray[1]} (${stringarray[0]}); "; done
    echo ""
    sleep 10s

}

# Stop strace in each node
# $1 = mode (genData | run)
# $2 = size (in GB)
# $3 = run
function strace_stop {
    echo "$LOG strace-stop: $1:$2:$3"

    STRACE_PIDS_TO_STOP=( "${STRACE_PIDS[@]}" )
    echo -n "$LOG strace-stop:  Killing Strace instances: "
    for a in "${STRACE_PIDS_TO_STOP[@]}"; do stringarray=($a); echo -n "${stringarray[1]} (${stringarray[0]}); "; done
    echo ""

    # stop strace instances
    for val in "${STRACE_PIDS_TO_STOP[@]}" ; do
        stringarray=($val)
        ip="${stringarray[0]}"
        node_pid="${stringarray[1]}"
        ssh $USER@${ip} "sudo kill -s SIGINT $node_pid"
    done

    echo "$LOG strace-stop:  Waiting for Strace instances to finish..."
    for val in "${STRACE_PIDS_TO_STOP[@]}" ; do
        stringarray=($val)
        ip="${stringarray[0]}"
        node_pid="${stringarray[1]}"
        ssh $USER@${ip} "while ps -p $node_pid >/dev/null 2>&1; do sleep 10; done"
    done

}

# Launch catstrace in each node
# $1 = mode (genData | run)
# $2 = size (in GB)
# $3 = run
function catstrace_launch {
    echo "$LOG catstrace-launch: $1:$2:$3"
    CATSTRACE_PIDS=()

     # for client
    echo -n "->>>>STRACE CLI SIZE:"
    ls -lsh /home/$USER/strace.out

    # for namenode
    namenode=(${hosts[0]})
    echo -n "->>>>STRACE NN$i  SIZE: "
    ssh $USER@${namenode[1]} "ls -lsh /home/$USER/strace.out"
    catstrace_pid=$(ssh $USER@${namenode[1]} "sudo -E catstrace --input /home/$USER/strace.out --whitelist $CONF_DIR/whitelist-bdb.txt --stats --esize 262144 --trace_output $RESULTS_PATH/$2G/trace-$1-$2G-namenode-$3.json &>/dev/null & echo \$!")
    CATSTRACE_PIDS+=("${namenode[1]} $catstrace_pid")

    # for datanodes
    for (( i=1; i<${#hosts[@]}; i++ )); do
        host_row=(${hosts[$i]})
        echo -n "->>>>STRACE DN$i  SIZE: "
        ssh $USER@${host_row[1]} "ls -lsh /home/$USER/strace.out"
        echo ""
        catstrace_pid=$(ssh $USER@${host_row[1]} "sudo -E catstrace --input /home/$USER/strace.out --whitelist $CONF_DIR/whitelist-bdb.txt --stats --esize 262144 --trace_output $RESULTS_PATH/$2G/trace-$1-$2G-datanode$i-$3.json &>/dev/null & echo \$!")
        CATSTRACE_PIDS+=("${host_row[1]} $catstrace_pid")
    done

    echo -n "$LOG strace-launch:  catstrace instances: "
    for a in "${CATSTRACE_PIDS[@]}"; do stringarray=($a); echo -n "${stringarray[1]} (${stringarray[0]}); "; done
    echo ""
    sleep 10s
}

# Stop strace in each node
# $1 = mode (genData | run)
# $2 = size (in GB)
# $3 = run
function catstrace_stop {
    echo "$LOG catstrace-stop: $1:$2:$3"

    CATSTRACE_PIDS_TO_STOP=( "${CATSTRACE_PIDS[@]}" )
    echo "$LOG strace-stop:  Waiting for catstrace instances to finish..."
    for val in "${CATSTRACE_PIDS_TO_STOP[@]}" ; do
        stringarray=($val)
        ip="${stringarray[0]}"
        node_pid="${stringarray[1]}"
        ssh $USER@${ip} "while ps -p $node_pid >/dev/null 2>&1; do sleep 10; done"
    done

    # copy data to $RESULTS_PATH for namenode
    namenode=(${hosts[0]})
    ssh $USER@${namenode[1]} "mv /home/$USER/catstrace.log $RESULTS_PATH/$2G/catstrace-$1-$2G-namenode-$3.txt;"
    ssh $USER@${namenode[1]} "mv /home/$USER/CatStrace-stats.json $RESULTS_PATH/$2G/catstrace-stats-$1-$2G-namenode$i-$3.txt;"
    ssh $USER@${namenode[1]} "sudo rm /home/$USER/strace.out;"

    # copy data to $RESULTS_PATH for datanodes
    for (( i=1; i<${#hosts[@]}; i++ )); do
        host_row=(${hosts[$i]})
        ssh $USER@${host_row[1]} "mv /home/$USER/catstrace.log $RESULTS_PATH/$2G/catstrace-$1-$2G-datanode$i-$3.txt;"
        ssh $USER@${host_row[1]} "mv /home/$USER/CatStrace-stats.json $RESULTS_PATH/$2G/catstrace-stats-$1-$2G-datanode$i-$3.txt;"
        ssh $USER@${host_row[1]} "sudo rm /home/$USER/strace.out;"
    done

    # copy data to $RESULTS_PATH for client
    mv catstrace.log $RESULTS_PATH/$2G/catstrace-$1-$2G-client-$3.txt
    mv CatStrace-stats.json $RUN_DIR/catstrace-stats-$1-$2G-client-$3.txt
    sudo rm /home/$USER/strace.out
}

# Run BigDataBench - Bayes - GenData
# $1 = size (in GB)
# $2 = run
# $3 = deployment (vanilla / catbpf / catstrace)
function gen_data_bdb {
    echo "$LOG gen_data_bdb-$2: $1 G"

    mkdir -p $RESULTS_PATH/$1G/
    for (( i=0; i<${#hosts[@]}; i++ )); do
        host_row=(${hosts[$i]})
		ssh $USER@${host_row[1]} "mkdir -p $RESULTS_PATH/$1G/"
	done

    cd $BDB_PATH

    echo "$LOG gen_data_bdb-$2: format hdfs"
    clean_up_hdfs
    ssh $USER@$MASTER_IP $HADOOP_PATH/sbin/start-dfs.sh

    # $HADOOP_PATH/bin/hdfs dfs -mkdir /hadoop/
    # $HADOOP_PATH/bin/hdfs dfs -mkdir -p /hadoop/Bayes/
    $HADOOP_PATH/bin/hdfs dfs -chown root /
    # $HADOOP_PATH/bin/hdfs dfs -chown root /hadoop/

    # start dstat
    dstat_launch genData "$1" "$2"

    # start tracer
    case $3 in
        vanilla)
            sudo -E /usr/bin/time --verbose --output=$RESULTS_PATH/$1G/time-genData-$1G-$2 ./genData-bayes.sh $1
            ;;
        catbpf)
            catbpf_launch genData "$1" "$2"
            sudo -E $CATBPF_BINARY_PATH/catbpf --stats --whitelist $CONF_DIR/whitelist-bdb.txt -log2file -c 4 /usr/bin/time --verbose --output=$RESULTS_PATH/$1G/time-genData-$1G-$2 ./genData-bayes.sh $1
            catbpf_stop genData "$1" "$2"
            ;;
        catstrace)
            strace_launch genData "$1" "$2"
            sudo -E strace -o /home/$USER/strace.out -e trace=open,openat,read,pread64,write,pwrite64,accept,accept4,connect,socket,recv,recvfrom,recvmsg,send,sendto,sendmsg -s 262144 -tt -yy -f /usr/bin/time --verbose --output=$RESULTS_PATH/$1G/time-genData-$1G-$2 ./genData-bayes.sh $1
            strace_stop genData "$1" "$2"
            ;;
    esac

    # stop dstat
    dstat_stop genData "$1" "$2"


    if [[ "$3" == "catstrace" ]]; then
        catstrace_launch genData "$1" "$2"
        sudo -E catstrace --input /home/$USER/strace.out --whitelist $CONF_DIR/whitelist-bdb.txt --stats --esize 262144 --trace_output $RESULTS_PATH/$1G/trace-genData-$1G-client-$2.json
        catstrace_stop genData "$1" "$2"
    fi


    sleep 30s
}

# Run BigDataBench - Bayes - Benchmark
# $1 = size (in GB)
# $2 = # runs
# $3 = deployment
function run_bdb {
    echo "$LOG run_bdb: $1 G, $2 runs, $3"

    mkdir -p $RESULTS_PATH/$1G/
    for (( i=0; i<${#hosts[@]}; i++ )); do
        host_row=(${hosts[$i]})
		ssh $USER@${host_row[1]} "mkdir -p $RESULTS_PATH/$1G/"
	done

    cd $BDB_PATH

    for (( run=1; run<($2+1); run++ )); do
        echo "$LOG run_bdb-$run: Generating data"

        gen_data_bdb "$1" "$run" "$3"

        echo "$LOG Loading-phase cooldown time: sleep $cool_down_time_load"
        sleep $cool_down_time_load

        echo "$LOG run_bdb-$run: Restarting HDFS"
        ssh $USER@$MASTER $HADOOP_PATH/sbin/stop-dfs.sh
        ssh $USER@$MASTER $HADOOP_PATH/sbin/start-dfs.sh

        echo "$LOG run_bdb-$run: Cleaning caches"
        $CAT_HDFS_DIR/tools/hdfs-clean-up.sh clean_cache

        echo $USER@"$LOG_IP run_bdb-$run: Starting run-bayes"

        # start dstat
        dstat_launch run "$1" "$run"

         # start tracer
        case $3 in
            vanilla)
                sudo -E /usr/bin/time --verbose --output=$RESULTS_PATH/$1G/time-run-$1G-$run ./run-bayes.sh
                ;;
            catbpf)
                catbpf_launch run "$1" "$run"
                sudo -E $CATBPF_BINARY_PATH/catbpf --stats --whitelist $CONF_DIR/whitelist-bdb.txt -log2file -c 6 /usr/bin/time --verbose --output=$RESULTS_PATH/$1G/time-run-$1G-$run ./run-bayes.sh
                catbpf_stop run "$1" "$run"
                ;;
            catstrace)
                strace_launch run "$1" "$run"
                sudo -E strace -o /home/$USER/strace.out -e trace=open,openat,read,pread64,write,pwrite64,accept,accept4,connect,socket,recv,recvfrom,recvmsg,send,sendto,sendmsg -s 262144 -tt -yy -f /usr/bin/time --verbose --output=$RESULTS_PATH/$1G/time-run-$1G-$run ./run-bayes.sh
                strace_stop run "$1" "$run"
                ;;
        esac

        # stop dstat
        dstat_stop run "$1" "$run"

        if [[ "$3" == "catstrace" ]]; then
            catstrace_launch run "$1" "$run"
            sudo -E catstrace --input /home/$USER/strace.out --whitelist $CONF_DIR/whitelist-bdb.txt --stats --esize 262144 --trace_output $RESULTS_PATH/$1G/trace-run-$1G-client-$run.json
            catstrace_stop run "$1" "$run"
        fi

        sleep 30s
    done

}



function run_macros {
    run_bdb 16
    run_bdb 32
}

"$@"
