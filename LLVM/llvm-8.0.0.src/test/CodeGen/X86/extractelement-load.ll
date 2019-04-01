; NOTE: Assertions have been autogenerated by utils/update_llc_test_checks.py
; RUN: llc < %s -mtriple=i686-unknown -mattr=+sse2 | FileCheck %s --check-prefix=X32-SSE2
; RUN: llc < %s -mtriple=x86_64-unknown -mattr=+ssse3 | FileCheck %s --check-prefix=X64-SSSE3
; RUN: llc < %s -mtriple=x86_64-unknown -mattr=+avx | FileCheck %s --check-prefix=X64-AVX

target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"

define i32 @t(<2 x i64>* %val) nounwind  {
; X32-SSE2-LABEL: t:
; X32-SSE2:       # %bb.0:
; X32-SSE2-NEXT:    movl {{[0-9]+}}(%esp), %eax
; X32-SSE2-NEXT:    movl 8(%eax), %eax
; X32-SSE2-NEXT:    retl
;
; X64-SSSE3-LABEL: t:
; X64-SSSE3:       # %bb.0:
; X64-SSSE3-NEXT:    movl 8(%rdi), %eax
; X64-SSSE3-NEXT:    retq
;
; X64-AVX-LABEL: t:
; X64-AVX:       # %bb.0:
; X64-AVX-NEXT:    movl 8(%rdi), %eax
; X64-AVX-NEXT:    retq
  %tmp2 = load <2 x i64>, <2 x i64>* %val, align 16		; <<2 x i64>> [#uses=1]
  %tmp3 = bitcast <2 x i64> %tmp2 to <4 x i32>		; <<4 x i32>> [#uses=1]
  %tmp4 = extractelement <4 x i32> %tmp3, i32 2		; <i32> [#uses=1]
  ret i32 %tmp4
}

; Case where extractelement of load ends up as undef.
; (Making sure this doesn't crash.)
define i32 @t2(<8 x i32>* %xp) {
; X32-SSE2-LABEL: t2:
; X32-SSE2:       # %bb.0:
; X32-SSE2-NEXT:    retl
;
; X64-SSSE3-LABEL: t2:
; X64-SSSE3:       # %bb.0:
; X64-SSSE3-NEXT:    retq
;
; X64-AVX-LABEL: t2:
; X64-AVX:       # %bb.0:
; X64-AVX-NEXT:    retq
  %x = load <8 x i32>, <8 x i32>* %xp
  %Shuff68 = shufflevector <8 x i32> %x, <8 x i32> undef, <8 x i32> <i32 undef, i32 7, i32 9, i32 undef, i32 13, i32 15, i32 1, i32 3>
  %y = extractelement <8 x i32> %Shuff68, i32 0
  ret i32 %y
}

; This case could easily end up inf-looping in the DAG combiner due to an
; low alignment load of the vector which prevents us from reliably forming a
; narrow load.

define void @t3(<2 x double>* %a0) {
; X32-SSE2-LABEL: t3:
; X32-SSE2:       # %bb.0: # %bb
; X32-SSE2-NEXT:    movl {{[0-9]+}}(%esp), %eax
; X32-SSE2-NEXT:    movupd (%eax), %xmm0
; X32-SSE2-NEXT:    movhpd %xmm0, (%eax)
; X32-SSE2-NEXT:    retl
;
; X64-SSSE3-LABEL: t3:
; X64-SSSE3:       # %bb.0: # %bb
; X64-SSSE3-NEXT:    movsd {{.*#+}} xmm0 = mem[0],zero
; X64-SSSE3-NEXT:    movsd %xmm0, (%rax)
; X64-SSSE3-NEXT:    retq
;
; X64-AVX-LABEL: t3:
; X64-AVX:       # %bb.0: # %bb
; X64-AVX-NEXT:    vmovsd {{.*#+}} xmm0 = mem[0],zero
; X64-AVX-NEXT:    vmovsd %xmm0, (%rax)
; X64-AVX-NEXT:    retq
bb:
  %tmp13 = load <2 x double>, <2 x double>* %a0, align 1
  %.sroa.3.24.vec.extract = extractelement <2 x double> %tmp13, i32 1
  store double %.sroa.3.24.vec.extract, double* undef, align 8
  ret void
}

; Case where a load is unary shuffled, then bitcast (to a type with the same
; number of elements) before extractelement.
; This is testing for an assertion - the extraction was assuming that the undef
; second shuffle operand was a post-bitcast type instead of a pre-bitcast type.
define i64 @t4(<2 x double>* %a) {
; X32-SSE2-LABEL: t4:
; X32-SSE2:       # %bb.0:
; X32-SSE2-NEXT:    movl {{[0-9]+}}(%esp), %eax
; X32-SSE2-NEXT:    movdqa (%eax), %xmm0
; X32-SSE2-NEXT:    movd %xmm0, %eax
; X32-SSE2-NEXT:    shufps {{.*#+}} xmm0 = xmm0[1,1,0,1]
; X32-SSE2-NEXT:    movd %xmm0, %edx
; X32-SSE2-NEXT:    retl
;
; X64-SSSE3-LABEL: t4:
; X64-SSSE3:       # %bb.0:
; X64-SSSE3-NEXT:    movq (%rdi), %rax
; X64-SSSE3-NEXT:    retq
;
; X64-AVX-LABEL: t4:
; X64-AVX:       # %bb.0:
; X64-AVX-NEXT:    movq (%rdi), %rax
; X64-AVX-NEXT:    retq
  %b = load <2 x double>, <2 x double>* %a, align 16
  %c = shufflevector <2 x double> %b, <2 x double> %b, <2 x i32> <i32 1, i32 0>
  %d = bitcast <2 x double> %c to <2 x i64>
  %e = extractelement <2 x i64> %d, i32 1
  ret i64 %e
}

