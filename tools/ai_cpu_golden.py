#!/usr/bin/env python3
"""Exact signed-INT8 DOT4ACC reference model used by Stage 27 validation."""
MASK32 = 0xffffffff
def s32(x):
    x &= MASK32
    return x - (1 << 32) if x & 0x80000000 else x
def s8(x):
    x &= 0xff
    return x - 256 if x & 0x80 else x
def dot4acc(acc, packed_a, packed_b):
    total = s32(acc)
    for lane in range(4):
        total += s8(packed_a >> (8 * lane)) * s8(packed_b >> (8 * lane))
    return total & MASK32
def dot4(a, b):
    return dot4acc(0, a, b)
def dot_product(values_a, values_b):
    if len(values_a) != len(values_b) or len(values_a) % 4:
        raise ValueError("DOT4 chunks require equal lengths divisible by four")
    acc = 0
    for i in range(0, len(values_a), 4):
        pa = sum((x & 0xff) << (8*j) for j, x in enumerate(values_a[i:i+4]))
        pb = sum((x & 0xff) << (8*j) for j, x in enumerate(values_b[i:i+4]))
        acc = dot4acc(acc, pa, pb)
    return acc
def matvec(weights, vector, biases=None):
    biases = biases or [0] * len(weights)
    return [dot_product(row, vector) + biases[i] & MASK32 for i, row in enumerate(weights)]
if __name__ == "__main__":
    print(f"DOT4(1,2,3,4;5,6,7,8)={dot4(0x04030201,0x08070605):08x}")
