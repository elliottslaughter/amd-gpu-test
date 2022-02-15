#!/bin/bash

set -e

# FIXME: probably need to put this in $MEMBERWORK, I remember I ran out of space last time
if [[ ! -e spack ]]; then
    git clone -c feature.manyFiles=true https://github.com/spack/spack.git
    first_time=1
fi

. spack/share/spack/setup-env.sh

if [[ -n $first_time ]]; then
    spack compiler find
fi

srun -N 1 -n 1 -A CHM137_crusher -t 02:00:00 -p batch --cpu-bind none --pty -- spack install hip@4.5.2 %gcc@10.3.0 build_type=Debug
