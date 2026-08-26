# Stage 31 tiny quantized network

This fixed integer network has four INT8 inputs, four hidden neurons, and two
INT32 output scores. Biases are signed INT32; ReLU is applied after the hidden
layer. No floating-point scale or requantization is used. The selected values
keep all ReLU outputs in the signed-INT8 range so they can be consumed by the
second layer without truncation.

## Network

```text
W1 = [[ 1,  1,  1,  1],
      [ 1, -1,  1, -1],
      [-1,  1, -1,  1],
      [ 1,  1, -1, -1]]
b1 = [0, 0, 0, 0]

W2 = [[ 1,  1,  1,  1],
      [ 1, -1,  1, -1]]
b2 = [0, 3]
```

The scalar baseline implements multiplication by the coefficients `-1`, `0`,
and `1` using supported ADD/SUB instructions. The optimized image uses one
DOT4ACC for each hidden neuron; output scoring and classification remain
scalar and identical in both programs.

## Test vectors and golden results

| Test | Input | Hidden after ReLU | Scores | Class |
|---|---|---|---|---:|
| 1 positive/simple | `[1,2,3,4]` | `[10,0,2,0]` | `[12,15]` | 1 |
| 2 mixed signed | `[3,-2,1,4]` | `[6,2,0,0]` | `[8,7]` | 0 |
| 3 ReLU edge | `[-1,-2,-3,-4]` | `[0,2,0,4]` | `[6,-3]` | 0 |
| 4 near boundary | `[4,1,2,-3]` | `[4,8,0,6]` | `[18,-7]` | 0 |

## Validation memory map

Optimized input word is at word index 16 (byte address 64), packed little-endian
INT8 lanes. Packed W1 rows are at indices 20..23 (byte addresses 80..92).
Baseline inputs are sign-extended words at indices 16..19. The sign mask
`0x80000000` is at index 30. Both programs store scores at indices 40 and 41
(byte addresses 160 and 164), and the class at index 42 (byte address 168).
