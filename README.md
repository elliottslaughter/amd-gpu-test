# Codes

  * `device_function`: An implementation of SAXPY using a device function in HIP/Terra, called from a common device kernel
  * `device_kernel`: An implementation of a SAXPY device kernel in HIP/Terra, called from a common host code

# Spock Quickstart

```
source spock_env.sh
./build.sh
make -C device_function
make -C device_kernel
salloc -N 1 -A $PROJECT_ID -t 01:00:00 -p ecp
srun device_function/saxpy_hip
srun device_function/saxpy_terra
srun device_kernel/saxpy_hip
srun device_kernel/saxpy_terra
```

# Documentation Links

 * Target triples: https://llvm.org/docs/AMDGPUUsage.html#target-triples
 * Processors (look for `gfx908`): https://llvm.org/docs/AMDGPUUsage.html#processors
 * Clang offload bundler: https://clang.llvm.org/docs/ClangOffloadBundler.html

# Notes

The HIP `.o` file seems to have been produced by a tool called
`clang-offload-bundler`:

```
$ clang-offload-bundler --list --inputs=test_hip.o --type=o
hip-amdgcn-amd-amdhsa-gfx908
host-x86_64-unknown-linux-gnu
```

You can use it to unpack the bundle too. Note that the component files
are LLVM bitcode.

```
clang-offload-bundler --unbundle --inputs=test_hip.o --type=o --outputs=test_hip.unbundle_device.bc --targets=hip-amdgcn-amd-amdhsa-gfx908
clang-offload-bundler --unbundle --inputs=test_hip.o --type=o --outputs=test_hip.unbundle_host.o --targets=host-x86_64-unknown-linux-gnu
llvm-dis test_hip.unbundle_device.bc
```
