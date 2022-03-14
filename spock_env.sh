module load PrgEnv-gnu
module load rocm/5.0.2

export TERRA_AMDGPU_TARGET=gfx908
export HIPCCFLAGS=--amdgpu-target=gfx908

export INCLUDE_PATH="$ROCM_PATH/include"

export PATH="$PATH:$ROCM_PATH/llvm/bin"
