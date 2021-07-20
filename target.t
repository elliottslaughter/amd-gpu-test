local amd_target = terralib.newtarget {
  Triple = 'amdgcn-amd-rocm-amdhsa',
  CPU = 'gfx908',
  FloatABIHard = true,
}

terra f(a : float, x : float, y : float)
  return a * x + y
end

terralib.saveobj("test.o", {f=f}, {}, amd_target)
