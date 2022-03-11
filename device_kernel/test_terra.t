local arch = os.getenv("TERRA_AMDGPU_TARGET") or 'gfx90a'
print("compiling for " .. arch)
local amd_target = terralib.newtarget {
  Triple = 'amdgcn-amd-amdhsa',
  CPU = arch,
  FloatABIHard = true,
}

local wgx = terralib.intrinsic("llvm.amdgcn.workgroup.id.x",{} -> int32)
local wix = terralib.intrinsic("llvm.amdgcn.workitem.id.x",{} -> int32)

terra f(a : float, x : float, y : float)
  return a * x + y
end

-- FIXME: need to get this through llvm.amdgcn.dispatch.ptr (I think) instead of hard-coding
local workgroup_size = 256

terra saxpy(num_elements : uint64, alpha : float,
            x : &float, y : &float, z : &float)
  var idx = wgx() * workgroup_size + wix()
  if idx < num_elements then
    z[idx] = z[idx] + alpha * x[idx] + y[idx]
  end
end
-- FIXME: need to set calling convention amdgpu_kernel by hand on this function

local function pr(...)
  print(...)
  return ...
end

terralib.saveobj("test_terra_device.ll", {saxpy=saxpy}, {}, amd_target)
os.execute(pr("sed -i -e 's/dso_local void/dso_local amdgpu_kernel void/g' test_terra_device.ll"))
os.execute(pr("llvm-as test_terra_device.ll"))
local f = assert(io.open("test_terra_device.bc", "rb"))
local device_bc = f:read("*all")
f:close()

-- Host code.
local c = terralib.includecstring [[
#include <stdio.h>
#include <stdlib.h>
#define __HIP_PLATFORM_HCC__ 1
#include <hip/hip_runtime.h>
]]

terra check(ok : c.hipError_t)
  if ok ~= c.HIP_SUCCESS then
    c.printf("error: %s\n", c.hipGetErrorName(ok))
    c.abort()
  end
end

-- The name and value of this variable don't actually matter. I'm
-- pretty sure this is just being used as a safe way to generate a
-- unique ID that can identify the kernel.
local saxpy = terralib.global({uint64, float, &float, &float, &float} -> {}, nil, "saxpy_handle")

terra stub(num_elements : uint64, alpha : float,
           x : &float, y : &float, z : &float) : {}
  var grid_dim : c.dim3
  var block_dim : c.dim3
  var shmem_size : uint64
  var stream : c.hipStream_t
  check(c.__hipPopCallConfiguration(&grid_dim, &block_dim, &shmem_size, &stream))

  var args : (&opaque)[5]
  args[0] = &num_elements
  args[1] = &alpha
  args[2] = &x
  args[3] = &y
  args[4] = &z

  c.printf("grid_dim.x %d, grid_dim.y %d, grid_dim.z %d\n", grid_dim.x, grid_dim.y, grid_dim.z);
  c.printf("block_dim.x %d, block_dim.y %d, block_dim.z %d\n", block_dim.x, block_dim.y, block_dim.z);

  c.printf("about to call hipLaunchKernel\n")

  check(c.hipLaunchKernel([&opaque](&saxpy), grid_dim, block_dim, args, shmem_size, stream))
end

local __hipRegisterFatBinary = terralib.externfunction("__hipRegisterFatBinary", {&int8} -> {&&int8})
local __hipRegisterFunction = terralib.externfunction("__hipRegisterFunction", {&&int8, &&int8, &int8, &int8, int32, &int8, &int8, &int8, &int8, &int32} -> {int32})

-- local __hip_fatbin = terralib.global(int8, nil, "__hip_fatbin", true)
struct fatbin_wrapper {
       a : int32,
       b : int32,
       c : &int8,
       d : &int8,
}
local __hip_fatbin_wrapper = terralib.global(fatbin_wrapper, `fatbin_wrapper{1212764230,1,device_bc --[[&__hip_fatbin]],nil})

terra ctor()
  c.printf("in ctor\n")
  c.printf("calling __hipRegisterFatBinary\n")
  var gpubin = __hipRegisterFatBinary([&int8](&__hip_fatbin_wrapper))
  c.printf("finished __hipRegisterFatBinary\n")
  c.printf("calling __hipRegisterFunction\n")
  var result = __hipRegisterFunction(gpubin, [&&int8](&saxpy), "saxpy", "saxpy", -1, nil, nil, nil, nil, nil)
  c.printf("finished __hipRegisterFunction with result %d\n", result)
  -- FIXME: install dtor
end

terralib.saveobj("test_terra_host.ll", {__device_stub__saxpy=stub, hip_module_ctor=ctor})
print("Please modify the file test_terra_host.ll as desired and then press ENTER to continue.")
io.read()
os.execute(pr("llvm-as test_terra_host.ll"))
os.execute(pr("llc -filetype=obj -O3 test_terra_host.bc -o test_terra_host.o"))
-- terralib.saveobj("test_terra_host.o", {__device_stub__saxpy=stub, hip_module_ctor=ctor})
