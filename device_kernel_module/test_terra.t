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

terra saxpy(num_elements : uint64, alpha : float,
            x : &float, y : &float, z : &float)
  var idx = wgx() * workgroup_size + wix()
  if idx < num_elements then
    z[idx] = z[idx] + alpha * x[idx] + y[idx]
  end
end
saxpy:setcallingconv("amdgpu_kernel")

local function pr(...)
  print(...)
  return ...
end

-- Save the kernel as an object file.
terralib.saveobj("test_terra_device.o", {saxpy=saxpy}, {}, amd_target)

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

  var args : (&opaque)[5]
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
  check(c.hipModuleGetFunction(&func, module, "saxpy"))
  c.printf("finished hipModuleGetFunction\n")
  -- FIXME: install dtor
end

terralib.saveobj("test_terra_host.o", {__device_stub__saxpy=stub, hip_module_ctor=ctor})
