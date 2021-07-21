local amd_target = terralib.newtarget {
  Triple = 'amdgcn-amd-amdhsa',
  CPU = 'gfx908',
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

struct dim3 {
  x : int32,
  y : int32,
  z : int32,
}
local stream = opaque

local hipLaunchKernel = terralib.externfunction("hipLaunchKernel", {&opaque, int64, int32, int64, int32, &&opaque, int64, &stream} -> {int32})

local hipPopCallConfiguration = terralib.externfunction("__hipPopCallConfiguration", {&dim3, &dim3, &int64, &&stream} -> {int32})

terra stub(num_elements : uint64, alpha : float,
           x : &float, y : &float, z : &float)
  var grid_dim : dim3
  var block_dim : dim3
  var shmem_size : int64
  var stream : &stream
  hipPopCallConfiguration(&grid_dim, &block_dim, &shmem_size, &stream)

  -- It looks like want to pack the first two dims into an int64
  var grid_dim12 = @[&int64](&grid_dim)
  var grid_dim3 = grid_dim.z
  var block_dim12 = @[&int64](&block_dim)
  var block_dim3 = block_dim.z

  var args : (&opaque)[5]
  args[0] = [&opaque](&num_elements)
  args[1] = [&opaque](&alpha)
  args[2] = [&opaque](&x)
  args[3] = [&opaque](&y)
  args[4] = [&opaque](&z)

  hipLaunchKernel([&opaque](saxpy), grid_dim12, grid_dim3, block_dim12, block_dim3, args, shmem_size, stream)
end

terralib.saveobj("test_terra_host.o", {__device_stub__saxpy=stub})
terralib.saveobj("test_terra_device.ll", {saxpy=saxpy}, {}, amd_target)
