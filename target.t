local amd_target = terralib.newtarget {
  Triple = 'amdgcn-amd-rocm-amdhsa',
  CPU = 'gfx908',
  FloatABIHard = true,
}

terra f(x : int)
  return x + 1
end

terralib.saveobj("test.o", {f=f}, {}, amd_target)
