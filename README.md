# Documentation Links

 * Target triples: https://llvm.org/docs/AMDGPUUsage.html#target-triples
 * Processors (look for `gfx908`): https://llvm.org/docs/AMDGPUUsage.html#processors
 * Clang offload bundler: https://clang.llvm.org/docs/ClangOffloadBundler.html

# Testing on Spock

```
source spock_env.sh
./build.sh
make
```

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
$ clang-offload-bundler --unbundle --inputs=test_hip.o --type=o --outputs=test_hip.unbundle.o --targets=hip-amdgcn-amd-amdhsa-gfx908
$ llvm-dis test_hip.unbundle.o
```
