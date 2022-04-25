#include <hip/hip_runtime.h>

#include "histogram.h"

__global__ void compute_histogram(const size_t num_elements, const float range,
                                  const float *data, unsigned *histogram) {
  int t = threadIdx.x;
  int nt = blockDim.x;

  __shared__ unsigned local_histogram[NUM_BUCKETS];
  for (int i = t; i < NUM_BUCKETS; i += nt) local_histogram[i] = 0;

  __syncthreads();

  for (int idx = (blockIdx.x * blockDim.x) + threadIdx.x; idx < num_elements;
       idx += gridDim.x * blockDim.x) {
    size_t bucket = floor(data[idx] / range * (NUM_BUCKETS - 1));
    atomicAdd(&local_histogram[bucket], 1);
  }

  __syncthreads();

  for (int i = t; i < NUM_BUCKETS; i += nt)
    atomicAdd(&histogram[i], local_histogram[i]);
}
