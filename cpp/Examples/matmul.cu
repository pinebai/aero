// Again Matrix Multiplication but now using shared memory. 

#include <iostream>
#include "../common/book.h"
using namespace std;

#define BLOCK_SIZE 16

typedef struct {
	int width;
	int height;
	int stride;
	float* elements;
	} Matrix;

__device__ float GetElement(const Matrix A, int row, int col)
{
	return A.elements[row*A.stride+col];
}

__device__ void SetElement(Matrix A, int row, int col, float value)
{
	A.elements[row*A.stride + col] = value;
}

__device__ Matrix GetSubMatrix(Matrix A, int row, int col)
{
	Matrix Asub;
	Asub.width  = BLOCK_SIZE;
	Asub.height = BLOCK_SIZE;
	Asub.stride = A.stride;
	Asub.elements = &A.elements[A.stride * BLOCK_SIZE * row + BLOCK_SIZE * col];
	return Asub;
}

__global__ void MatMultKernel (Matrix A, Matrix B, Matrix C)
{
	int blockRow = blockIdx.y;
	int blockCol = blockIdx.x;

	Matrix Csub = GetSubMatrix(C, blockRow, blockCol);

	float Cvalue = 0;
	
	int row = threadIdx.y;
	int col = threadIdx.x;
	
	for(int m = 0; m < (A.width / BLOCK_SIZE); ++m) 
	{
		Matrix Asub = GetSubMatrix(A, blockRow, m);
		Matrix Bsub = GetSubMatrix(B, m, blockCol);
	
		__shared__ float As [BLOCK_SIZE][BLOCK_SIZE];
		__shared__ float Bs [BLOCK_SIZE][BLOCK_SIZE];
	
		As[row][col] = GetElement(Asub, row, col);
		Bs[row][col] = GetElement(Bsub, row, col);
	
		__syncthreads();

	for (int e = 0; e < BLOCK_SIZE; ++e)
		Cvalue += As[row][e] * Bs[e][col];

		__syncthreads();
	}
	SetElement(Csub, row, col, Cvalue);
}

/*
int random(int t)
{
	srand((unsigned)time(0));
	t = (rand()%10)+1;
	return t;
}
*/

#define MATRIX_SIZE 128

int main() 
{
	Matrix A;
	A.width = MATRIX_SIZE;
	A.height = MATRIX_SIZE;
	A.stride = A.width;
	for (int i=0; i<A.width*A.height ;i++)
	{	
		A.elements[i]=1; //random();
	}
	
	Matrix B;
	B.width = MATRIX_SIZE;
	B.height = MATRIX_SIZE;
	B.stride = B.width;
	for (int j=0; j<B.width*B.height ;j++)
	{
		B.elements[j]=1; //random();
	}

	Matrix C;
	C.width = MATRIX_SIZE;
	C.height = MATRIX_SIZE;
	C.stride = C.width;

	cout << "matrix A, B and C loaded \n";
		
	Matrix d_A;
	d_A.width = d_A.stride = A.width;
	d_A.height = A.height;
	size_t size = A.width * A.height * sizeof(float);
	cudaMalloc (&d_A.elements, size);
	cudaMemcpy (d_A.elements, A.elements, size, cudaMemcpyHostToDevice);
	
	Matrix d_B;
	d_B.width = d_B.stride = B.width;
	d_B.height = B.height;
	size = B.width * B.height * sizeof(float);
	cudaMalloc (&d_B.elements, size);
	cudaMemcpy (d_A.elements, A.elements, size, cudaMemcpyHostToDevice);

	cout << "matrix d_A, d_B allocated in device \n";	

	Matrix d_C;
	d_C.width = d_C.stride = C.width;
	d_C.height = C.height;
	size = C.width * C.height * sizeof(float);
	cudaMalloc (&d_C.elements, size);

	cout << "Initalize Kernel \n";

	dim3 dimBlock(BLOCK_SIZE,BLOCK_SIZE);
	dim3 dimGrid(B.width / dimBlock.x, A.height /dimBlock.y);
	MatMultKernel<<<dimGrid,dimBlock>>>(d_A,d_B,d_C);

	cout << "Computation succesfull! \ncopying results \n";

	cudaMemcpy(C.elements, d_C.elements, size, cudaMemcpyDeviceToHost);

	cudaFree(d_A.elements);
	cudaFree(d_B.elements);
	cudaFree(d_C.elements);
	
return 0;
}
