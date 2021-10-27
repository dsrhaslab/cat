#!/bin/bash

# https://www.tensorflow.org/datasets/catalog/imagenette#imagenettefull-size

function verify_package {
    PACKAGE_INSTALLED=$(dpkg-query -W -f='${Status}' $1 2>/dev/null | grep -c "ok installed")
    if [ $PACKAGE_INSTALLED -eq 0 ]; then
        sudo apt update -y
        sudo apt install -y $1
    fi
}

function download_imagennet_full_size {
    verify_package wget
    wget https://s3.amazonaws.com/fast-ai-imageclas/imagenette2.tgz
    tar xf imagenette2.tgz
    mv imagenette2/val imagenette2/validation
    ls imagenette2/train/ | cat  > imagenette2/synset_labels.txt
    rm imagenette2.tgz

}

download_imagennet_full_size