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

cd hip_dev/samples/0_Intro/module_api

# some debugging of the object file format
clang-offload-bundler --list --inputs=vcpy_kernel.code --type=o
# host-x86_64-unknown-linux
# hipv4-amdgcn-amd-amdhsa--gfx90a

clang-offload-bundler --unbundle --inputs=vcpy_kernel.code --type=o --outputs=vcpy_kernel.unbundle_device.o --targets=hipv4-amdgcn-amd-amdhsa--gfx90a
clang-offload-bundler --unbundle --inputs=vcpy_kernel.code --type=o --outputs=vcpy_kernel.unbundle_host.o --targets=host-x86_64-unknown-linux

#llvm-dis vcpy_kernel.unbundle_device.o
# llvm-dis: error: file doesn't start with bitcode header

nm vcpy_kernel.unbundle_device.o
# 0000000000002000 d _DYNAMIC
# 0000000000001000 T hello_world
# 0000000000000680 R hello_world.kd

file vcpy_kernel.unbundle_device.o
# vcpy_kernel.unbundle_device.o: ELF 64-bit LSB shared object, version 1, dynamically linked, not stripped

# note: need to be on a node with a GPU for this to work:
# ./launchKernelHcc.hip.out
