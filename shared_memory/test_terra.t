local arch = os.getenv("TERRA_AMDGPU_TARGET") or 'gfx90a'
print("compiling for " .. arch)
local amd_target = terralib.newtarget {
  Triple = 'amdgcn-amd-amdhsa',
  CPU = arch,
  FloatABIHard = true,
}

local wgx = terralib.intrinsic("llvm.amdgcn.workgroup.id.x",{} -> int32)
local wix = terralib.intrinsic("llvm.amdgcn.workitem.id.x",{} -> int32)

-- FIXME: need to get this through llvm.amdgcn.dispatch.ptr (I think) instead of hard-coding
local workgroup_size = 256

local grid_size = 4 -- FIXME: don't think we can hard-code this

local histogram_h = terralib.includec("histogram.h", {"-I."})
local NUM_BUCKETS = histogram_h.NUM_BUCKETS

local floor = terralib.intrinsic("llvm.floor.f32", {float}->float)

terra histogram(num_elements : uint64, range : float,
                data : &float, histogram : &uint32)
  var t = wix()
  var nt = workgroup_size

  -- FIXME: how do we do this with shared memory?
  var local_histogram : uint32[NUM_BUCKETS]

  for i = t, NUM_BUCKETS, nt do
    local_histogram[i] = 0
  end

  -- FIXME: how to __syncthreads?

  for idx = (wgx() * workgroup_size) + wix(), num_elements, grid_size * workgroup_size do
    var bucket = floor(data[idx] / range * (NUM_BUCKETS - 1));
    terralib.atomicrmw("add", &local_histogram[idx], 1, {ordering = "monotonic"})
  end

  -- FIXME: how to __syncthreads?

  for i = t, NUM_BUCKETS, nt do
    terralib.atomicrmw("add", &histogram[i], local_histogram[i], {ordering = "monotonic"})
  end
end
histogram:setcallingconv("amdgpu_kernel")

local function pr(...)
  print(...)
  return ...
end

-- Save the kernel as an object file.
print(terralib.saveobj(nil, "llvmir", {histogram=histogram}, {}, amd_target, false))
terralib.saveobj("test_terra_device.o", {histogram=histogram}, {}, amd_target)

-- Link the kernel into a shared library.
os.execute(pr("ld.lld -shared -plugin-opt=mcpu=" .. arch .. " -plugin-opt=-amdgpu-internalize-symbols -plugin-opt=O3 -plugin-opt=-amdgpu-early-inline-all=true -plugin-opt=-amdgpu-function-calls=false -o test_terra_device.so test_terra_device.o"))

-- Bundle the shared library.
-- Note the use of /dev/null for the host portion.
os.execute(pr("clang-offload-bundler --inputs=/dev/null,test_terra_device.so --type=o --outputs=test_terra.o --targets=host-x86_64-unknown-linux-gnu,hipv4-amdgcn-amd-amdhsa--" .. arch))

-- Now read the whole thing so we can embed it in the host code.
local f = assert(io.open("test_terra.o", "rb"))
local device_code = f:read("*all")
f:close()

-- Host code.
local c = terralib.includecstring [[
#include <stdio.h>
#include <stdlib.h>
#define __HIP_PLATFORM_HCC__ 1
#include <hip/hip_runtime.h>
]]

-- There's no reason these have to be globals, just used here to match interface the rest of the code is expecting.
local module = terralib.global(c.hipModule_t, nil, "module")
local func = terralib.global(c.hipFunction_t, nil, "func")

terra check(ok : c.hipError_t)
  if ok ~= c.HIP_SUCCESS then
    c.printf("error: %s\n", c.hipGetErrorName(ok))
    c.abort()
  end
end

terra stub(num_elements : uint64, alpha : float,
           x : &float, y : &float, z : &float) : {}
  var grid_dim : c.dim3
  var block_dim : c.dim3
  var shmem_size : uint64
  var stream : c.hipStream_t
  check(c.__hipPopCallConfiguration(&grid_dim, &block_dim, &shmem_size, &stream))

  var args : (&opaque)[7]
  args[0] = &num_elements
  args[1] = &alpha
  args[2] = &x
  args[3] = &y
  args[4] = &z

  c.printf("grid_dim.x %d, grid_dim.y %d, grid_dim.z %d\n", grid_dim.x, grid_dim.y, grid_dim.z);
  c.printf("block_dim.x %d, block_dim.y %d, block_dim.z %d\n", block_dim.x, block_dim.y, block_dim.z);

  c.printf("about to call hipModuleLaunchKernel\n")
  check(c.hipModuleLaunchKernel(
          func,
          grid_dim.x, grid_dim.y, grid_dim.z,
          block_dim.x, block_dim.y, block_dim.z,
          shmem_size,
          stream,
          args,
          nil))
end

terra ctor()
  c.printf("in ctor\n")
  c.printf("calling hipModuleLoadData\n")
  -- var module : c.hipModule_t
  check(c.hipModuleLoadData(&module, device_code))
  c.printf("finished hipModuleLoadData\n")
  c.printf("calling hipModuleGetFunction\n")
  -- var func : c.hipFunction_t
  check(c.hipModuleGetFunction(&func, module, "histogram"))
  c.printf("finished hipModuleGetFunction\n")
  -- FIXME: install dtor
end

terralib.saveobj("test_terra_host.o", {__device_stub__compute_histogram=stub, hip_module_ctor=ctor})
