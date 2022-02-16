#!/bin/bash

set -e

source crusher_env.sh

if [[ ! -e hip_dev ]]; then
    git clone -b eds/testing https://github.com/elliottslaughter/HIP.git hip_dev
fi

cd hip_dev/samples/0_Intro/module_api
export HIPCC_FLAGS="$HIPCCFLAGS"
export GENCO_FLAGS="$HIPCCFLAGS"
make
