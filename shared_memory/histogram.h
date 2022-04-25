#ifndef HISTOGRAM_H
#define HISTOGRAM_H

#define NUM_BUCKETS 128

__global__ extern "C" void compute_histogram(const size_t num_elements, const float range,
                                             const float *data, unsigned *histogram);

#endif
