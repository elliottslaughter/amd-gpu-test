module load PrgEnv-gnu
module load rocm

export TERRA_AMDGPU_TARGET=gfx908
export HIPCCFLAGS=--amdgpu-target=gfx908

export INCLUDE_PATH="$ROCM_PATH/include"

export LLVM_ROOT="$PWD/../llvm-13-src-lld/install"

export PATH="$PATH:$LLVM_ROOT/bin"

# export PATH="$PATH:$ROCM_PATH/llvm/bin"
