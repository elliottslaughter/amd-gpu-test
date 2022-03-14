#!/bin/bash

set -e

target="$(hostname --fqdn)"
if [[ $target = *.crusher.* ]]; then
    source crusher_env.sh
elif [[ $target = *.spock.* ]]; then
    source spock_env.sh
else
    echo "Don't know how to build on this machine."
    exit 1
fi

if [[ ! -e legion ]]; then
    git clone -b master https://gitlab.com/StanfordLegion/legion.git
fi

cd legion/language
CC=cc CXX=CC HOST_CC=gcc HOST_CXX=g++ USE_GASNET=0 ./scripts/setup_env.py --llvm-version=130 --terra-url https://github.com/terralang/terra.git --terra-branch master

