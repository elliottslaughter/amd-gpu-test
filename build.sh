#!/bin/bash

set -e

source spock_env.sh

if [[ ! -e legion ]]; then
    git clone -b master https://gitlab.com/StanfordLegion/legion.git
fi

cd legion/language
CC=cc CXX=CC HOST_CC=gcc HOST_CXX=g++ USE_GASNET=0 ./scripts/setup_env.py --llvm-version=110 --terra-url https://github.com/terralang/terra.git --terra-branch master

