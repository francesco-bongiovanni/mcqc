#include <iostream>
#include "benchmark.h"
#include "Fib.cpp"

#define N 38
using namespace Nat;

// For benchmarking against autogen version
unsigned int fib2(unsigned int n) {
	if (n == 0 || n == 1) { return 1; }
	else { return add(fib(n-1), fib(n-2)); }
}
// Overflows
unsigned int fib2_unsafe(unsigned int n) {
	if (n == 0 || n == 1) { return 1; }
	else { return fib(n-1) + fib(n-2); }
}

// Overflows, is not recursive
unsigned int fib2_fast(unsigned int n) {
    unsigned int j=1, k=1, sum;
	for (unsigned int i=1; i<n; ++i) {
		sum=j+k;
		j=k;
		k=sum;
	}
    return k;
}

int main() {
    std::cout << "========== Native recursive (safe) fib " << N << std::endl;
	tic();
	std::cerr << fib2(N) << std::endl;
	toc();

	std::cout << "========== Native recursive (unsafe) fib " << N << std::endl;
    tic();
	std::cerr << fib2_unsafe(N) << std::endl;
	toc();

    std::cout << "========== Native fast (unsafe) fib " << N << std::endl;
	tic();
	std::cerr << fib2_fast(N) << std::endl;
	toc();

	// Nats, autogenerated at Fib.cpp
    std::cout << "========== Autogenerated recursive (safe) fib " << N << std::endl;
	tic();
	std::cerr << fib(N) << std::endl;
	toc();

    return 0;
}
