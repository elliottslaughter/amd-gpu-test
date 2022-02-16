#!/bin/bash

set -e

source crusher_env.sh

if [[ ! -e hip_dev ]]; then
    git clone -b eds/testing https://github.com/elliottslaughter/HIP.git hip_dev
fi

export HIPCC_FLAGS="$HIPCCFLAGS"
export GENCO_FLAGS="$HIPCCFLAGS"
make -C hip_dev/samples/1_Utils/hipInfo hipInfo
make -C hip_dev/samples/0_Intro/module_api

# note: need to be on a node with a GPU for this to work:
cd hip_dev/samples/0_Intro/module_api
./launchKernelHcc.hip.out
