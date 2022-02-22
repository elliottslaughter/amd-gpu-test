#include <hip/hip_runtime.h>

__global__ extern "C" void saxpy(
                      const size_t num_elements, const float alpha,
                      const float *x, const float *y, float *z);

__global__ void saxpy(const size_t num_elements, const float alpha,
                      const float *x, const float *y, float *z) {
  int idx = (blockIdx.x * blockDim.x) + threadIdx.x;
  if (idx < num_elements) z[idx] += alpha * x[idx] + y[idx];
}
