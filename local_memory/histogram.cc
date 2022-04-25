#include <hip/hip_runtime.h>
#include <stdio.h>

#include "histogram.h"

__global__ extern "C" void compute_histogram(const size_t num_elements, const float range,
                                             const float *data, unsigned *histogram);

#ifdef TERRA_HACK
extern "C" void hip_module_ctor();
#endif

int main() {
#ifdef TERRA_HACK
  printf("running Terra hack\n");
  hip_module_ctor();
  printf("finished Terra hack\n");
  fflush(stdout);
#endif

  size_t num_elements = 1 << 20;
  size_t data_size = num_elements * sizeof(float);
  size_t histogram_size = NUM_BUCKETS * sizeof(unsigned);

  float *data = (float *)malloc(data_size);
  unsigned *histogram = (unsigned *)malloc(histogram_size);

  float *d_data;
  unsigned *d_histogram;
  hipMalloc(&d_data, data_size);
  hipMalloc(&d_histogram, histogram_size);

  float range = (float)RAND_MAX;
  for (size_t idx = 0; idx < num_elements; idx++) {
    data[idx] = rand();
  }
  for (size_t idx = 0; idx < NUM_BUCKETS; idx++) {
    histogram[idx] = 0;
  }

  hipMemcpyAsync(d_data, data, data_size, hipMemcpyHostToDevice);
  hipMemcpyAsync(d_histogram, histogram, histogram_size, hipMemcpyHostToDevice);

  size_t elts_per_thread = 16;
  size_t block_size = 256;
  size_t blocks = (num_elements + elts_per_thread * block_size - 1) /
                  (elts_per_thread * block_size);
  compute_histogram<<<blocks, block_size>>>(num_elements, range, d_data,
                                            d_histogram);

  hipMemcpyAsync(histogram, d_histogram, histogram_size, hipMemcpyDeviceToHost);

  hipDeviceSynchronize();

  size_t total = 0;
  for (size_t idx = 0; idx < NUM_BUCKETS; idx++) {
    total += histogram[idx];
    printf("histogram[%lu] = %u\n", idx, histogram[idx]);
  }
  printf("\ntotal = %lu (%s)\n", total,
         total == num_elements ? "PASS" : "FAIL");

  hipFree(d_data);
  hipFree(d_histogram);

  free(data);
  free(histogram);

  return 0;
}
