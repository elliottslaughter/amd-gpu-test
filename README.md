# Codes

  * `device_function`: A device function in HIP/Terra, called from a HIP device kernel/host code
  * `device_kernel`: A device kernel in HIP/Terra, via `__hipRegisterFatBinary`, called from a HIP host code
  * `device_kernel_module`: A device kernel in HIP/Terra, via `hipModuleLoadData`, called from a HIP host code

# Status

  * `device_function`: Working
  * `device_kernel`: Works with the following workarounds:
      * Need to manually modify the host code fatbin to reference device code via:

        ```
        @__hip_fatbin = external constant i8, section ".hip_fatbin"
        @__hip_fatbin_wrapper = internal constant { i32, i32, i8*, i8* } { i32 1212764230, i32 1, i8* @__hip_fatbin, i8* null }, section ".hipFatBinSegment", align 8
        ```

        (And pass this to `__hipRegisterFatBinary`.)

      * Need to manually set `amdgpu_kernel` calling convention on kernel.
      * Work group size is currently hard-coded.
  * `device_kernel_module`: Works with the following workarounds:
      * Need to manually set `amdgpu_kernel` calling convention on kernel.
      * Work group size is currently hard-coded.

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
 * [`__hipRegisterFatBinary` docs](https://rocmdocs.amd.com/en/latest/Programming_Guides/hipporting-driver-api.html#initialization-and-termination-functions)
    * [implementation](https://github.com/ROCm-Developer-Tools/hipamd/blob/c681345d78600325ac7db92156ee7829ac50b695/src/hip_platform.cpp#L87)
 * For comparison, [NVIDIA's fatbin format (note the magic number)](https://github.com/StanfordLegion/legion/blob/c10271d6ecb7ca1c92cfabf5d76e4a76444f9300/language/src/regent/cudahelper.t#L46)
 * [module API example code](https://github.com/ROCm-Developer-Tools/HIP/blob/09583b01835af26bc94d917364ac100e03424adc/samples/0_Intro/module_api/launchKernelHcc.cpp)
    * note the use of [`--genco` to generate this output file](https://github.com/ROCm-Developer-Tools/HIP/blob/09583b01835af26bc94d917364ac100e03424adc/samples/0_Intro/module_api/Makefile#L41)
 * [Logging levels](https://github.com/ROCm-Developer-Tools/HIP/blob/develop/docs/markdown/hip_logging.md#hip-logging-level)

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

# Tracing `__hipRegisterFatBinary`

  * [`__hipRegisterFatBinary`](https://github.com/ROCm-Developer-Tools/hipamd/blob/6d1262c56061cf63a44cde77c9205912e67c278d/src/hip_platform.cpp#L76)
      * calls [`PlatformState::addFatBinary`](https://github.com/ROCm-Developer-Tools/hipamd/blob/6d1262c56061cf63a44cde77c9205912e67c278d/src/hip_platform.cpp#L84)
  * (for comparison, [`hipModuleLoadData`](https://github.com/ROCm-Developer-Tools/hipamd/blob/6d1262c56061cf63a44cde77c9205912e67c278d/src/hip_module.cpp#L63))
      * calls [`PlatformState::loadModule`](https://github.com/ROCm-Developer-Tools/hipamd/blob/6d1262c56061cf63a44cde77c9205912e67c278d/src/hip_module.cpp#L67)
  * [`PlatformState::addFatBinary`](https://github.com/ROCm-Developer-Tools/hipamd/blob/6d1262c56061cf63a44cde77c9205912e67c278d/src/hip_platform.cpp#L889)
      * calls [`statCO_.addFatBinary`](https://github.com/ROCm-Developer-Tools/hipamd/blob/6d1262c56061cf63a44cde77c9205912e67c278d/src/hip_platform.cpp#L890)
      * this seems to go through [`hip::StatCO`](https://github.com/ROCm-Developer-Tools/hipamd/blob/6d1262c56061cf63a44cde77c9205912e67c278d/src/hip_platform.hpp#L94)
      * defined [here](https://github.com/ROCm-Developer-Tools/hipamd/blob/6d1262c56061cf63a44cde77c9205912e67c278d/src/hip_code_object.hpp#L125)
  * [`StatCO::addFatBinary`](https://github.com/ROCm-Developer-Tools/hipamd/blob/6d1262c56061cf63a44cde77c9205912e67c278d/src/hip_code_object.cpp#L705)
      * calls [`digestFatBinary`](https://github.com/ROCm-Developer-Tools/hipamd/blob/6d1262c56061cf63a44cde77c9205912e67c278d/src/hip_code_object.cpp#L709)
      * defined [here](https://github.com/ROCm-Developer-Tools/hipamd/blob/6d1262c56061cf63a44cde77c9205912e67c278d/src/hip_code_object.cpp#L691)
      * calls [`programs->ExtractFatBinary`](https://github.com/ROCm-Developer-Tools/hipamd/blob/6d1262c56061cf63a44cde77c9205912e67c278d/src/hip_code_object.cpp#L700)
      * `FatBinaryInfo` is defined [here](https://github.com/ROCm-Developer-Tools/hipamd/blob/de01ce04677243116dba52b59406a130517ea4c7/src/hip_fatbin.hpp#L36)
  * [`FatBinaryInfo::ExtractFatBinary`](https://github.com/ROCm-Developer-Tools/hipamd/blob/c681345d78600325ac7db92156ee7829ac50b695/src/hip_fatbin.cpp#L49)
    * calls [`CodeObject::ExtractCodeObjectFromFile`](https://github.com/ROCm-Developer-Tools/hipamd/blob/c681345d78600325ac7db92156ee7829ac50b695/src/hip_fatbin.cpp#L71)
    * also [`CodeObject::ExtractCodeObjectFromMemory`](https://github.com/ROCm-Developer-Tools/hipamd/blob/c681345d78600325ac7db92156ee7829ac50b695/src/hip_fatbin.cpp#L76)
    * `CodeObject` defined [here](https://github.com/ROCm-Developer-Tools/hipamd/blob/6d1262c56061cf63a44cde77c9205912e67c278d/src/hip_code_object.hpp#L43)
  * [`CodeObject::ExtractCodeObjectFromFile`](https://github.com/ROCm-Developer-Tools/hipamd/blob/6d1262c56061cf63a44cde77c9205912e67c278d/src/hip_code_object.cpp#L378)
      * calls [`extractCodeObjectFromFatBinary`](https://github.com/ROCm-Developer-Tools/hipamd/blob/6d1262c56061cf63a44cde77c9205912e67c278d/src/hip_code_object.cpp#L396)
      * defined [here](https://github.com/ROCm-Developer-Tools/hipamd/blob/6d1262c56061cf63a44cde77c9205912e67c278d/src/hip_code_object.cpp#L416)
      * **THIS SEEMS TO BE THE PLACE WHERE THEY PARSE THE CLANG OFFLOAD BUNDLER API**
  * ([`PlatformState::loadModule`](https://github.com/ROCm-Developer-Tools/hipamd/blob/6d1262c56061cf63a44cde77c9205912e67c278d/src/hip_platform.cpp#L743))
