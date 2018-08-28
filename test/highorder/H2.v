(**
    RUN: %coqc %s
    RUN: %clean
    RUN: %machcoq H2.json -o %t.cpp
    RUN: FileCheck %s -check-prefix=CPP < %t.cpp

    CPP: #include "nat.hpp"
    CPP: template<{{typename|class}} [[TT:.?]], {{typename|class}} [[TT2:.?]]>
    CPP: Nat onOddEven([[TT]] fo, [[TT2]] fe, Nat n)
*)

Fixpoint isEven(n: nat) :=
  match n with
    | 0 => true
    | 1 => false
    | S(S m as sm) => isEven m
  end.

Definition onOddEven (fo : nat -> bool) (fe : nat -> nat) (n: nat) :=
  match (isEven n) with
    | true => fe n
    | false => if fo n then 1 else 0
  end.

Require Extraction.
Extraction Language JSON.
Separate Extraction onOddEven.
