(**
    RUN: %coqc %s
    RUN: %clean
    RUN: %machcoq Fib.json -o %t.cpp
    RUN: FileCheck %s -check-prefix=CPP < %t.cpp
    RUN: %clang %t.cpp -emit-llvm -g -S -o %t.ll %s
    RUN: FileCheck %s -check-prefix=LLVM < %t.ll

    CPP: #include "nat.hpp"
    CPP: Nat fib(Nat n)
    CPP: return match{{.*}}n{{.*}}
    CPP: return (Nat)1;
    CPP: return match{{.*}}sm{{.*}}
    CPP: return (Nat)1;
    CPP: add{{.*}}fib(m){{.*}}
    CPP: fib(sm)

    LLVM: define i32 @{{.*}}fib{{.*}}
    LLVM: icmp eq i32 [[NN:%[0-9]+]], 0
    LLVM: [[SM:%[0-9]+]] = add i32 [[NN]], -1
    LLVM: icmp eq i32 [[SM]], 0
    LLVM: [[MM:%[0-9]+]] = add i32 [[NN]], -2
    LLVM: {{.*}} call {{.*}}i32 @{{.*}}fib{{.*}}[[MM]]
    LLVM: {{.*}} call {{.*}}i32 @{{.*}}fib{{.*}}[[SM]]
*)

Require Extraction.

Fixpoint fib(n: nat) :=
  match n with
    | 0 => 1
    | 1 => 1
    | S(S m as sm) => fib(m) + fib(sm)
  end.
Extraction Language JSON.
Separate Extraction fib.
