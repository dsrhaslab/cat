#!/bin/bash

JAVA_VERSION=openjdk-8-jdk
JAVA_HOME=java-8-openjdk-amd64

function update {
  sudo apt -y update
  sudo apt -y upgrade
}

function install_properties {
    sudo apt install -y software-properties-common python-software-properties vim git maven lvm2 parted screen time bc
    sudo apt install -y dstat sysstat ltrace strace
}


function java-jdk {
  sudo apt update
  sudo apt install -y $JAVA_VERSION
  sudo apt update
}

function all {
  update
  install_properties
  java-jdk
}

"$@"