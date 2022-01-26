# Codes

  * `device_function`: A device function in HIP/Terra, called from a HIP device kernel/host code
  * `device_kernel`: A device kernel in HIP/Terra, called from a HIP host code

# Crusher Quickstart

```
source crusher_env.sh
./build.sh
make -C device_function
make -C device_kernel
salloc -N 1 -A $PROJECT_ID -t 01:00:00 -p batch
srun device_function/saxpy_hip
srun device_function/saxpy_terra
srun device_kernel/saxpy_hip
srun device_kernel/saxpy_terra
```

# Documentation Links

 * Target triples: https://llvm.org/docs/AMDGPUUsage.html#target-triples
 * Processors (look for `gfx90a`): https://llvm.org/docs/AMDGPUUsage.html#processors
 * Clang offload bundler: https://clang.llvm.org/docs/ClangOffloadBundler.html
 * `__hipRegisterFunction`: https://rocmdocs.amd.com/en/latest/Programming_Guides/hipporting-driver-api.html#initialization-and-termination-functions
 * For comparison, NVIDIA's fatbin format (note the magic number): https://github.com/StanfordLegion/legion/blob/c10271d6ecb7ca1c92cfabf5d76e4a76444f9300/language/src/regent/cudahelper.t#L46

# Notes

The HIP `.o` file seems to have been produced by a tool called
`clang-offload-bundler`:

```
$ clang-offload-bundler --list --inputs=test_hip.o --type=o
hip-amdgcn-amd-amdhsa-gfx90a
host-x86_64-unknown-linux-gnu
```

You can use it to unpack the bundle too. Note that the device file is
LLVM bitcode, while the host file is object code. You can compile with
the `-emit-llvm` flag in order to have both be LLVM bitcode.

```
clang-offload-bundler --unbundle --inputs=test_hip.o --type=o --outputs=test_hip.unbundle_device.bc --targets=hip-amdgcn-amd-amdhsa-gfx90a
clang-offload-bundler --unbundle --inputs=test_hip.o --type=o --outputs=test_hip.unbundle_host.o --targets=host-x86_64-unknown-linux-gnu
```

If you do use bitcode, the `llvm-dis` command is useful to conver this
back into textual LLVM IR.

```
llvm-dis test_hip.unbundle_device.bc
```