module load PrgEnv-gnu
module load rocm

export HIPCCFLAGS=--amdgpu-target=gfx90a

export PATH="$PATH:$ROCM_PATH/llvm/bin"
# export LLVM_AS="$ROCM_PATH/llvm/bin/llvm-as"
# export LLVM_DIS="$ROCM_PATH/llvm/bin/llvm-dis"
# export CLANG_OFFLOAD_BUNDLER="$ROCM_PATH/llvm/bin/clang-offload-bundler"
