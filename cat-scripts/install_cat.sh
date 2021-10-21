#!/usr/bin/env bash

REQUIRED_PYTHON_VERSION=3.8
REQUIRED_KERNEL_VERSION=5.4
CURRENT_KERNEL_VERSION=$(uname -r | cut -c1-3)
CAT_PATH="$HOME/cat"


# -------------
# CatBpf
# -------------

function verify_catbpf_requirements {
    # Install bc if not already installed
    verify_package "bc"

    # Check kernel version
    if (( $(echo "$CURRENT_KERNEL_VERSION < $REQUIRED_KERNEL_VERSION" | bc -l) )); then
        echo "Kernel version: $CURRENT_KERNEL_VERSION < Version required: $REQUIRED_KERNEL_VERSION "
        echo "Please upgrade kernel version to $REQUIRED_KERNEL_VERSION."
        echo "Run './install_cat.sh upgrade_kernel_version'"
        exit
    fi

    # Check bcc tools
    /usr/share/bcc/tools/argdist -h > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        install_bcc
    fi

    # Check Go
    go version > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        install_go
    fi

}

function install_catbpf_requirements {
    install_bcc
    install_go
}

function install_catbpf {
    clone_cat
    CUR_DIR=$(pwd)

    verify_catbpf_requirements

    echo -e "\n-----------------------------------\n"
    echo -e "--> Installing CatBpf:"
    echo -e "\n-----------------------------------\n"
    cd $CAT_PATH/catracer/catbpf
    go install
    if [ $? -eq 0 ]; then
        echo -e "\nCatBpf was successfully installed!\nRun 'sudo $CUR_DIR/go/bin/catbpf --help' to see the available options"
    else
        echo -e "Failed to install CatBpf"
    fi
    cd $CUR_DIR
}

# -------------
# CatStrace
# -------------

function verify_catstrace_requirements {
    # Install bc if not already installed
    verify_package "bc"

    CURRENT_PYTHON3_VERISON=$(python3 -V  | cut -d" " -f2 |  cut -c1-3)
    if (( $(echo "$CURRENT_PYTHON3_VERISON < $REQUIRED_PYTHON_VERSION" | bc -l) )); then
        install_python3
    fi

    # Install strace if not already installed
    strace -V > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        install_strace
    fi
}

function install_catstrace_requirements {
    install_python3
    install_strace
}

function install_catstrace {
    clone_cat
    CUR_DIR=$(pwd)

    verify_catstrace_requirements

    echo -e "\n-----------------------------------\n"
    echo -e "--> Installing CatStrace:"
    echo -e "\n-----------------------------------\n"
    cd $CAT_PATH/catracer/catstrace
    sudo pip3 install -e .
    if [ $? -eq 0 ]; then
        echo -e "\nCatStrace was successfully installed!\nRun 'sudo catstrace --help' to see the available options"
    else
        echo -e "Failed to install CatStrace"
    fi
    cd $CUR_DIR
}

# ---------
# CaTracers
# ---------

function install_catracers {
    install_catbpf
    install_catstrace
}

# -------------
# Falcon-Solver
# -------------

function install_falcon_solver {
    clone_cat
    verify_package "maven"
    verify_package "z3"

    CUR_DIR=$(pwd)
    cd $CAT_PATH/falcon-taz
    mvn package install

    cd $CAT_PATH/falcon-solver
    mvn package

    cd $CUR_DIR

}

# ---------
# CaSolvers
# ---------

function install_casolver_go {
    clone_cat
    CUR_DIR=$(pwd)

    echo -e "\n-----------------------------------\n"
    echo -e "--> Installing CaSolver-Go:"
    echo -e "\n-----------------------------------\n"

    # Check Go
    go version > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        install_go
    fi

    cd $CAT_PATH/casolver/casolver-go/
    go install
    if [ $? -eq 0 ]; then
        echo -e "\nCaSolver-Go was successfully installed!\nRun 'sudo $CUR_DIR/go/bin/casolver-go -h' to see the available options"
    else
        echo -e "Failed to install CaSolver-Go"
    fi
    cd $CUR_DIR
}

function install_casolver_py {
    clone_cat
    CUR_DIR=$(pwd)

    echo -e "\n-----------------------------------\n"
    echo -e "--> Installing CaSolver-Py:"
    echo -e "\n-----------------------------------\n"

    # Check Python3
    CURRENT_PYTHON3_VERISON=$(python3 -V  | cut -d" " -f2 |  cut -c1-3)
    if (( $(echo "$CURRENT_PYTHON3_VERISON < $REQUIRED_PYTHON_VERSION" | bc -l) )); then
        install_python3
    fi

    cd $CAT_PATH/casolver/casolver-py/
    sudo pip3 install -e .
    if [ $? -eq 0 ]; then
        echo -e "\nCaSolver-py was successfully installed!\nRun 'casolver-py -h' to see the available options"
    else
        echo -e "Failed to install CaSolver-py"
    fi
    cd $CUR_DIR
    cd $CUR_DIR
}

function install_casolvers {
    install_casolver_go
    install_casolver_py
}


# -----------------
# Falcon-Visualizer
# -----------------

function install_falcon_visualizer {
    clone_cat
    $CUR_DIR=$(pwd)
    verify_package "nodejs"
    verify_package "npm"
    verify_package "curl"
    sudo npm cache clean -f
    sudo npm install -g n
    sudo n stable
    curl -sL https://deb.nodesource.com/setup_12.x | sudo -E bash -
    sudo apt-get install -y nodejs

    CUR_DIR=$(pwd)
    cd $CAT_PATH/falcon-visualizer/
    npm install
    cd $CUR_DIR
}

# ---
# CaT
# ---

function clone_cat {
    CUR_DIR=$(pwd)
    cd $HOME
    verify_package "git"
    if [ ! -d "$CAT_PATH" ] ; then
        git clone --recursive  https://github.com/dsrhaslab/cat.git
    fi
    cd $CUR_DIR
}

function install_cat {
    clone_cat
    install_catracers
    install_falcon_solver
    install_casolvers
    install_falcon_visualizer
}


function install_cat_pipeline {
    install_falcon_solver
    install_casolvers
    install_falcon_visualizer
}

# -----

# $1: package name
function verify_package {
    PACKAGE_INSTALLED=$(dpkg-query -W -f='${Status}' $1 2>/dev/null | grep -c "ok installed")
    if [ $PACKAGE_INSTALLED -eq 0 ]; then
        sudo apt update -y
        sudo apt install -y $1
    fi
}

# -----

function upgrade_kernel_version {
    echo -e "\n-----------------------------------\n"
    echo -e "--> Checking kernel version:"
    echo -e "\n-----------------------------------\n"

    # Install bc if not already installed
    verify_package "bc"

    if (( $(echo "$CURRENT_KERNEL_VERSION < $REQUIRED_KERNEL_VERSION" | bc -l) )); then
        echo "Kernel version: $CURRENT_KERNEL_VERSION < Version required: $REQUIRED_KERNEL_VERSION "
        echo "Do you wish to install kernel version $REQUIRED_KERNEL_VERSION?"
        select yn in "Yes" "No"; do
            case $yn in
                Yes )
                    install_kernel_version
                    break
                    ;;
                No )
                    exit
                    ;;
            esac
        done
        echo "done"
    else
        echo "Kernel version ok! Required version is: $REQUIRED_KERNEL_VERSION and current kernel version is $CURRENT_KERNEL_VERSION. "
    fi
}

function install_kernel_version {
    echo -e "\n-----------------------------------\n"
    echo -e "--> Instaling kernel version $REQUIRED_KERNEL_VERSION:"
    echo -e "\n-----------------------------------\n"

    # Install wget if not already installed
    verify_package "wget"

    CUR_DIR=$(pwd)
    mkdir -p "kernel$REQUIRED_KERNEL_VERSION" && cd "kernel$REQUIRED_KERNEL_VERSION"
    pwd
    wget -c https://kernel.ubuntu.com/~kernel-ppa/mainline/v5.4/linux-headers-5.4.0-050400_5.4.0-050400.201911242031_all.deb

    wget -c https://kernel.ubuntu.com/~kernel-ppa/mainline/v5.4/linux-headers-5.4.0-050400-generic_5.4.0-050400.201911242031_amd64.deb

    wget -c https://kernel.ubuntu.com/~kernel-ppa/mainline/v5.4/linux-image-unsigned-5.4.0-050400-generic_5.4.0-050400.201911242031_amd64.deb

    wget -c https://kernel.ubuntu.com/~kernel-ppa/mainline/v5.4/linux-modules-5.4.0-050400-generic_5.4.0-050400.201911242031_amd64.deb

    sudo dpkg -i *.deb

    cd $CUR_DIR
    rm -r "kernel$REQUIRED_KERNEL_VERSION"

    echo "Reboot required! Do you wish to reboot now?"
    select yn in "Yes" "No"; do
        case $yn in
            Yes )
                sudo reboot
                break
                ;;
            No )
                exit
                ;;
        esac
    done
}

# -----

function install_bcc {
    echo -e "\n-----------------------------------\n"
    echo -e "--> Installing BCC tools:"
    echo -e "\n-----------------------------------\n"

    # Install git if not already installed
    verify_package "git"

    CUR_DIR=$(pwd)
    sudo apt update -y
    sudo apt install -y software-properties-common
    sudo apt-get -y install bison build-essential cmake flex git libedit-dev libllvm6.0 llvm-6.0-dev libclang-6.0-dev python zlib1g-dev libelf-dev
	sudo apt-get -y install luajit luajit-5.1-dev
    sudo apt-get -y install arping netperf iperf3
    sudo apt install python-distutils python3.8-distutils
    sudo apt-get install -y python3.8-dev
	git clone https://github.com/iovisor/bcc.git
	cd bcc;

    git checkout e41f7a3be5c8114ef6a0990e50c2fbabea0e928e
	mkdir build; cd build
	cmake ..
	make
	sudo make install
	cmake -DPYTHON_CMD=python3.8 ..
	pushd src/python/
	make
	sudo make install
    popd
    cd $CUR_DIR
}

# -----

function install_go {

    echo -e "\n-----------------------------------\n"
    echo -e "--> Installing GO:"
    echo -e "\n-----------------------------------\n"

    # Install wget if not already installed
    verify_package "wget"

    CUR_DIR=$(pwd)
    sudo apt-get install build-essential python3-pip -y
    wget https://dl.google.com/go/go1.14.4.linux-amd64.tar.gz
    sudo tar -C /usr/local -xzf go1.14.4.linux-amd64.tar.gz
    GOPATH="/usr/local/go/bin"
    echo "export PATH=$PATH:/usr/local/go/bin" >> ~/.bashrc
    export PATH=$PATH:/usr/local/go/bin
    go version
    rm go1.14.4.linux-amd64.tar.gz
    cd $CUR_DIR
    echo -e "\n>>> Run 'source ~/.bashrc' to apply the changes"
}

# ----

function install_python3 {
    echo -e "\n-----------------------------------\n"
    echo -e "--> Installing Python3.8:"
    echo -e "\n-----------------------------------\n"
    sudo apt update -y
    sudo apt install -y software-properties-common

    sudo add-apt-repository ppa:deadsnakes/ppa
    sudo apt update -y
    sudo apt install -y python3.8
    sudo update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.6 1
    sudo update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.8 2
    sudo update-alternatives --config python3
    python3.8 --version

    sudo apt-get install -y libssl-dev
    sudo apt-get install -y python3.8-dev
    sudo apt install python3.8-distutils

    sudo apt remove -y python3-pip
    sudo apt install -y python3-pip
    pip3 --version

}

# -----

function install_strace {
    echo -e "\n-----------------------------------\n"
    echo -e "--> Installing Strace:"
    echo -e "\n-----------------------------------\n"
    sudo apt-get install -y strace
}

# -----

function usage {
    echo "install_cat.sh usage:"
    echo -e "\t- Run './install_cat.sh install_catbpf' to install CatBpf."
    echo -e "\t- Run './install_cat.sh install_catstrace' to install CatStrace."
    echo -e "\t- Run './install_cat.sh install_catracers' to install both CaT tracers."
    echo -e "\t- Run './install_cat.sh install_falcon_solver' to install Falcon-Solver."
    echo -e "\t- Run './install_cat.sh install_casolver_go' to install CaSolver-Go."
    echo -e "\t- Run './install_cat.sh install_casolver_py' to install CaSolver-Py."
    echo -e "\t- Run './install_cat.sh install_casolvers' to install both CaSolvers."
    echo -e "\t- Run './install_cat.sh install_falcon_visualizer' to install Falcon-Visualizer."
    echo -e "\t- Run './install_cat.sh install_cat_pipeline' to install CaT's analysis pipeline (Falcon-Solver, CaSolvers, Falcon-Visualizer)"
    echo -e "\t- Run './install_cat.sh install_cat' to install all CaT's components (CaTracers, Falcon-Solver, CaSolvers, Falcon-Visualizer)"
}

"$@"