local amd_target = terralib.newtarget {
  Triple = 'amdgcn-amd-amdhsa',
  CPU = 'gfx90a',
  FloatABIHard = true,
}

terra f(a : float, x : float, y : float)
  return a * x + y
end

terralib.saveobj("test_terra_host.o", {})
terralib.saveobj("test_terra_device.ll", {f=f}, {}, amd_target)
