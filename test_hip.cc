#include <hip/hip_runtime.h>

__device__ extern "C" float f(float a, float x, float y);

__device__ float f(float a, float x, float y) {
  return a * x + y;
}
