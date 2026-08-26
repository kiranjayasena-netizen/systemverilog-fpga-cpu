#!/usr/bin/env python3
"""Generate the fixed Stage 31 scalar and DOT4ACC instruction images."""
from pathlib import Path

OP = dict(ADD=1, SUB=2, AND=3, ADDI=6, LOAD=7, STORE=8, BEQ=9, DOT=12)
R0, RIN, RW, RMASK, RBASE, RACC = 0, 20, 21, 22, 23, 24
H = [8, 9, 10, 11]

def rr(op, rd, a, b): return (OP[op]<<28)|(rd<<23)|(a<<18)|(b<<13)
def ri(op, rd, a, imm): return (OP[op]<<28)|(rd<<23)|(a<<18)|(imm & 0x1fff)

def emit_hidden(p, optimized, weights):
    for i, row in enumerate(weights):
        rd = H[i]
        if optimized:
            p += [ri('ADDI', rd, 0, 0), ri('LOAD', 1, RIN, 0),
                  ri('LOAD', 2, RW, i*4), rr('DOT', rd, 1, 2)]
        else:
            p += [ri('ADDI', rd, 0, 0)]
            for j, w in enumerate(row):
                if w == 1: p += [rr('ADD', rd, rd, 4+j)]
                elif w == -1: p += [rr('SUB', rd, rd, 4+j)]
        # ReLU: sign-mask test; negative values are replaced with zero.
        p += [rr('AND', RACC, rd, RMASK), 0, ri('ADDI', rd, 0, 0)]
        # Replace placeholder branch with BEQ-to-positive continuation.
        branch = len(p)-2
        p[branch] = ri('BEQ', 0, RACC, 0)
        p.append(0)  # positive continuation label placeholder
        p[branch] = ri('BEQ', 0, RACC, len(p)+1-branch)

def build(optimized):
    p = [ri('ADDI', RIN, 0, 64), ri('ADDI', RW, 0, 80),
         ri('ADDI', RMASK, 0, 120), ri('LOAD', RMASK, RMASK, 0), 0, 0, 0,
         ri('ADDI', RBASE, 0, 160)]
    if optimized:
        p.append(ri('LOAD', 1, RIN, 0))
        # The packed input remains in r1; each hidden DOT loads its weight.
        for i in range(4):
            p += [ri('ADDI', H[i], 0, 0), ri('LOAD', 2, RW, i*4), rr('DOT', H[i], 1, 2)]
            p += [rr('AND', RACC, H[i], RMASK), 0, ri('ADDI', H[i], 0, 0)]
            branch = len(p)-2; p.append(0); p[branch] = ri('BEQ', 0, RACC, len(p)+1-branch)
    else:
        for j in range(4):
            p.append(ri('LOAD', 4+j, RIN, j*4))
            p.extend([0, 0, 0])
        emit_hidden(p, False, [[1,1,1,1],[1,-1,1,-1],[-1,1,-1,1],[1,1,-1,-1]])
    # Output scores: y0 = h0+h1+h2+h3; y1 = h0-h1+h2-h3+3.
    p += [ri('ADDI', 12, 0, 0), rr('ADD',12,12,8), rr('ADD',12,12,9),
          rr('ADD',12,12,10), rr('ADD',12,12,11),
          ri('ADDI',13,0,3), rr('ADD',13,13,8), rr('SUB',13,13,9),
          rr('ADD',13,13,10), rr('SUB',13,13,11),
          ri('STORE',12,RBASE,0), ri('STORE',13,RBASE,4)]
    # class = (y0-y1 < 0), using sign mask; final store is completion event.
    p += [rr('SUB',14,12,13), rr('AND',RACC,14,RMASK), ri('ADDI',15,0,0),
          ri('BEQ',0,RACC,3), ri('ADDI',15,0,1), ri('STORE',15,RBASE,8)]
    p += [0]
    return p

def write(name, p):
    Path('programs', name).write_text(''.join(f'{x:08x}\n' for x in p))
    print(name, len(p))

write('ai_tiny_nn_baseline.mem', build(False))
write('ai_tiny_nn_dot4acc.mem', build(True))
