local amd_target = terralib.newtarget {
  Triple = 'amdgcn-amd-amdhsa',
  CPU = 'gfx908',
  FloatABIHard = true,
}

local wgx = terralib.intrinsic("llvm.amdgcn.workgroup.id.x",{} -> int)
local wix = terralib.intrinsic("llvm.amdgcn.workitem.id.x",{} -> int)

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

terra stub(num_elements : uint64, alpha : float,
           x : &float, y : &float, z : &float)
  -- FIXME: need to call hipLaunchKernel
end

terralib.saveobj("test_terra_host.o", {__device_stub__saxpy=stub})
terralib.saveobj("test_terra_device.ll", {saxpy=saxpy}, {}, amd_target)
