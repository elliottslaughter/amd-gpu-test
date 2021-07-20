#include <hip/hip_runtime.h>

__device__ float f(float a, float x, float y) {
  return a * x + y;
}
