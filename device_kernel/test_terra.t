local amd_target = terralib.newtarget {
  Triple = 'amdgcn-amd-amdhsa',
  CPU = 'gfx90a',
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

local __hipPopCallConfiguration = terralib.externfunction("__hipPopCallConfiguration", {&dim3, &dim3, &int64, &&stream} -> {int32})

local hipSuccess = 0
local hipGetErrorName = terralib.externfunction("hipGetErrorName", {int32} -> {rawstring})

local saxpyExtern = terralib.externfunction("saxpy", {uint64, float, &float, &float, &float} -> {})

local c = terralib.includec("stdio.h")

terra stub(num_elements : uint64, alpha : float,
           x : &float, y : &float, z : &float) : {}
  var grid_dim : dim3
  var block_dim : dim3
  var shmem_size : int64
  var stream : &stream
  __hipPopCallConfiguration(&grid_dim, &block_dim, &shmem_size, &stream)

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

  c.printf("about to call hipLaunchKernel\n")

  var result = hipLaunchKernel([&opaque](stub), grid_dim12, grid_dim3, block_dim12, block_dim3, args, shmem_size, stream)
  if result ~= hipSuccess then
    c.printf("error: %s\n", hipGetErrorName(result))
  end
end

local __hipRegisterFatBinary = terralib.externfunction("__hipRegisterFatBinary", {&int8} -> {&&int8})
local __hipRegisterFunction = terralib.externfunction("__hipRegisterFunction", {&&int8, &int8, &int8, &int8, int32, &int8, &int8, &int8, &int8, &int32} -> {int32})

local __hip_fatbin = terralib.global(int8, nil, "__hip_fatbin", true)
struct fatbin_wrapper {
       a : int32,
       b : int32,
       c : &int8,
       d : &int8,
}
local __hip_fatbin_wrapper = terralib.global(fatbin_wrapper, `fatbin_wrapper{1212764230,1,&__hip_fatbin,nil})

terra ctor()
  c.printf("in ctor\n")
  var gpubin = __hipRegisterFatBinary([&int8](&__hip_fatbin_wrapper))
  __hipRegisterFunction(gpubin, [&int8](stub), "saxpy", "saxpy", -1, nil, nil, nil, nil, nil)
  -- FIXME: install dtor
end

terralib.saveobj("test_terra_host.o", {__device_stub__saxpy=stub, hip_module_ctor=ctor})
terralib.saveobj("test_terra_device.ll", {saxpy=saxpy}, {}, amd_target)
