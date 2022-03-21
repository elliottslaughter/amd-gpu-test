module load PrgEnv-gnu
module load rocm/4.5.0

export TERRA_AMDGPU_TARGET=gfx90a
export HIPCCFLAGS=--amdgpu-target=gfx90a

export INCLUDE_PATH="$ROCM_PATH/include"

export PATH="$PATH:$ROCM_PATH/llvm/bin"
# export LLVM_AS="$ROCM_PATH/llvm/bin/llvm-as"
# export LLVM_DIS="$ROCM_PATH/llvm/bin/llvm-dis"
# export CLANG_OFFLOAD_BUNDLER="$ROCM_PATH/llvm/bin/clang-offload-bundler"
