local amd_target = terralib.newtarget {
  Triple = 'amdgcn-amd-rocm-amdhsa',
  CPU = 'gfx908',
  FloatABIHard = true,
}

terra f(a : float, x : float, y : float)
  return a * x + y
end

terralib.saveobj("test_terra_host.ll", {})
terralib.saveobj("test_terra_device.ll", {f=f}, {}, amd_target)
