
#include "cuda_runtime.h"
#include "device_launch_parameters.h"


#include <stdio.h>


cudaError_t addWithCuda(int *c, const int *a, const int *b, unsigned int size);

__global__ void addKernel(int *c, const int *a, const int *b)
{
    int i = threadIdx.x;
    c[i] = a[i] + b[i];
}

//rows determined as the amount of rows in a block
// A is query vector, B is the model ( rows ), C is output matrix
// Rows should be 300 for proper usage of this access method
__global__ void DotProduct
(int rows, float *A, float *B, float *C, float normA, float *normsB) {
  __shared__ float fastA[300];
  int id = blockIdx.x * blockDim.x + threadIdx.x;
  if (id<300) {
      fastA[id]=A[id];
  }
  __syncthreads();
  float acum=0;
  for(int i=0;i<300;++i) {
      acum+=fastA[i]*B[id*300+i];
  }
  C[id]=acum/(normA*normsB[id]);
}


__global__ void FirstMerge
(int N, float *sims, int length) {

  
    int id = blockIdx.x * blockDim.x + threadIdx.x;
    int start=id*N;
    int end=start+N;
    if (!(start>length)) { 
    
    // Insertion sort, as N SHOULD be small
   int key, j;
   for(int i = start+1; i<end; i++) {
      key = sims[i];
      j = i;
      while(j > 0 && sims[j-1]<key) {
         sims[j] = sims[j-1];
         j--;
      }
      sims[j] = key;  
   }
}
}



extern "C"
int runCuda()
{
    const int arraySize = 10;
    //const int a[arraySize] = { 1, 2, 3, 4, 5 };
    float sims[arraySize] = { 10, 20, 30, 40, 50,1,5,6,38,123};
    //int c[arraySize] = { 0 };
    
    
    int end=arraySize;
    int start=0;
   int key, j;
   for(int i = start+1; i<end; i++) {
      key = sims[i];
      j = i;
      while(j > 0 && sims[j-1]<key) {
         sims[j] = sims[j-1];
         j--;
      }
      sims[j] = key;  
   }
    for (int i=0;i<arraySize;++i){
        printf("{%f} ",
        sims[i]);

    }
    return 0;

/*
    // Add vectors in parallel.
    cudaError_t cudaStatus = addWithCuda(c, a, b, arraySize);
    if (cudaStatus != cudaSuccess) {
        fprintf(stderr, "addWithCuda failed!");
        return 1;
    }

    printf("{1,2,3,4,5} + {10,20,30,40,50} = {%d,%d,%d,%d,%d}\n",
        c[0], c[1], c[2], c[3], c[4]);

    // cudaDeviceReset must be called before exiting in order for profiling and
    // tracing tools such as Nsight and Visual Profiler to show complete traces.
    cudaStatus = cudaDeviceReset();
    if (cudaStatus != cudaSuccess) {
        fprintf(stderr, "cudaDeviceReset failed!");
        return 1;
    }
	
    return 0;
    */
}

// Helper function for using CUDA to add vectors in parallel.
cudaError_t addWithCuda(int *c, const int *a, const int *b, unsigned int size)
{
    int *dev_a = 0;
    int *dev_b = 0;
    int *dev_c = 0;
    cudaError_t cudaStatus;

    // Choose which GPU to run on, change this on a multi-GPU system.
    cudaStatus = cudaSetDevice(0);
    if (cudaStatus != cudaSuccess) {
        fprintf(stderr, "cudaSetDevice failed!  Do you have a CUDA-capable GPU installed?");
        goto Error;
    }

    // Allocate GPU buffers for three vectors (two input, one output)    .
    cudaStatus = cudaMalloc((void**)&dev_c, size * sizeof(int));
    if (cudaStatus != cudaSuccess) {
        fprintf(stderr, "cudaMalloc failed!");
        goto Error;
    }

    cudaStatus = cudaMalloc((void**)&dev_a, size * sizeof(int));
    if (cudaStatus != cudaSuccess) {
        fprintf(stderr, "cudaMalloc failed!");
        goto Error;
    }

    cudaStatus = cudaMalloc((void**)&dev_b, size * sizeof(int));
    if (cudaStatus != cudaSuccess) {
        fprintf(stderr, "cudaMalloc failed!");
        goto Error;
    }

    // Copy input vectors from host memory to GPU buffers.
    cudaStatus = cudaMemcpy(dev_a, a, size * sizeof(int), cudaMemcpyHostToDevice);
    if (cudaStatus != cudaSuccess) {
        fprintf(stderr, "cudaMemcpy failed!");
        goto Error;
    }

    cudaStatus = cudaMemcpy(dev_b, b, size * sizeof(int), cudaMemcpyHostToDevice);
    if (cudaStatus != cudaSuccess) {
        fprintf(stderr, "cudaMemcpy failed!");
        goto Error;
    }

    // Launch a kernel on the GPU with one thread for each element.
    addKernel<<<1, size>>>(dev_c, dev_a, dev_b);

    // Check for any errors launching the kernel
    cudaStatus = cudaGetLastError();
    if (cudaStatus != cudaSuccess) {
        fprintf(stderr, "addKernel launch failed: %s\n", cudaGetErrorString(cudaStatus));
        goto Error;
    }
    
    // cudaDeviceSynchronize waits for the kernel to finish, and returns
    // any errors encountered during the launch.
    cudaStatus = cudaDeviceSynchronize();
    if (cudaStatus != cudaSuccess) {
        fprintf(stderr, "cudaDeviceSynchronize returned error code %d after launching addKernel!\n", cudaStatus);
        goto Error;
    }

    // Copy output vector from GPU buffer to host memory.
    cudaStatus = cudaMemcpy(c, dev_c, size * sizeof(int), cudaMemcpyDeviceToHost);
    if (cudaStatus != cudaSuccess) {
        fprintf(stderr, "cudaMemcpy failed!");
        goto Error;
    }

Error:
    cudaFree(dev_c);
    cudaFree(dev_a);
    cudaFree(dev_b);
    
    return cudaStatus;
}