local arch = os.getenv("TERRA_AMDGPU_TARGET") or 'gfx90a'
print("compiling for " .. arch)
local amd_target = terralib.newtarget {
  Triple = 'amdgcn-amd-amdhsa',
  CPU = arch,
  FloatABIHard = true,
}

local wgx = terralib.intrinsic("llvm.amdgcn.workgroup.id.x",{} -> int32)
local wix = terralib.intrinsic("llvm.amdgcn.workitem.id.x",{} -> int32)

local histogram_h = terralib.includec("histogram.h", {"-I."})
local NUM_BUCKETS = histogram_h.NUM_BUCKETS

local floor = terralib.intrinsic("llvm.floor.f32", {float}->float)

-- Need this to generate
-- @_ZZ17compute_histogramE15local_histogram = internal unnamed_addr addrspace(3) global [128 x i32] undef, align 16
--
-- currently generates
-- @local_histogram = addrspace(3) global [128 x i32] undef
local as_local = 3
local local_histogram = terralib.global(uint32[NUM_BUCKETS], nil, "local_histogram", nil, nil, as_local) -- FIXME: missing internal/unnamed/align

local as_constant = 4
local dispatch_ptr = terralib.intrinsic("llvm.amdgcn.dispatch.ptr", {}->terralib.types.pointer(int8, as_constant))

local barrier = terralib.intrinsic("llvm.amdgcn.s.barrier", {}->{})

terra syncthreads()
  -- FIXME: probably synchronizing more aggressively than required, but the syncscope seems to be broken
  terralib.fence({ordering="release"})--, syncscope="workgroup"})
  barrier()
  terralib.fence({ordering="acquire"})--, syncscope="workgroup"})
end
syncthreads:setinlined(true)

terra histogram(num_elements : uint64, range : float,
                data : &float, histogram : &uint32)
  var dp = dispatch_ptr()

  -- Note: this fails:
  -- var dp4 = dp+4

  var wgsx = ([terralib.types.pointer(int16, as_constant)](dp))[2]
  var gsx = ([terralib.types.pointer(int32, as_constant)](dp))[3]

  var t = wix()
  var nt = wgsx

  for i = t, NUM_BUCKETS, nt do
    local_histogram[i] = 0
  end

  syncthreads()

  for idx = (wgx() * wgsx) + wix(), num_elements, gsx do
    var bucket = uint64(floor(data[idx] / range * (NUM_BUCKETS - 1)))
    terralib.atomicrmw("add", &local_histogram[bucket], 1, {ordering = "monotonic"})
  end

  syncthreads()

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

terra stub(num_elements : uint64, range : float,
           data : &float, histogram : &uint32) : {}
  var grid_dim : c.dim3
  var block_dim : c.dim3
  var shmem_size : uint64
  var stream : c.hipStream_t
  check(c.__hipPopCallConfiguration(&grid_dim, &block_dim, &shmem_size, &stream))

  var args : (&opaque)[4]
  args[0] = &num_elements
  args[1] = &range
  args[2] = &data
  args[3] = &histogram

  c.printf("grid_dim.x %d, grid_dim.y %d, grid_dim.z %d\n", grid_dim.x, grid_dim.y, grid_dim.z);
  c.printf("block_dim.x %d, block_dim.y %d, block_dim.z %d\n", block_dim.x, block_dim.y, block_dim.z);
  c.printf("shmem_size %llu\n", shmem_size)

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
