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

terra saxpy(num_elements : uint64, alpha : float,
            x : &float, y : &float, z : &float)
  var idx = wgx() + wix()
  if idx < num_elements then
    z[idx] = z[idx] + alpha * x[idx] + y[idx]
  end
end

-- Save the kernel as an object file.
terralib.saveobj("test_terra_device.o", {saxpy=saxpy}, {}, amd_target)

local function pr(...)
  print(...)
  return ...
end

-- Link the kernel into a shared library.
os.execute(pr("ld.lld -shared -plugin-opt=mcpu=" .. arch .. " -plugin-opt=-amdgpu-internalize-symbols -plugin-opt=O3 -plugin-opt=-amdgpu-early-inline-all=true -plugin-opt=-amdgpu-function-calls=false -o test_terra_device.so test_terra_device.o"))

-- Bundle the shared library.
-- Note the use of /dev/null for the host portion.
os.execute(pr("clang-offload-bundler --inputs=/dev/null,test_terra_device.so --type=o --outputs=test_terra.o --targets=host-x86_64-unknown-linux-gnu,hipv4-amdgcn-amd-amdhsa-" .. arch))

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
  var args : (&opaque)[5]
  args[0] = &num_elements
  args[1] = &alpha
  args[2] = &x
  args[3] = &y
  args[4] = &z

  var stream : c.hipStream_t
  c.printf("about to call hipStreamCreate\n")
  check(c.hipStreamCreate(&stream))
  c.printf("about to call hipModuleLaunchKernel\n")
  check(c.hipModuleLaunchKernel(
          func,
          (num_elements+255)/256, 1, 1, -- global work size
                             256, 1, 1, -- block size
          0, -- shared memory bytes
          stream,
          &(args[0]),
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
