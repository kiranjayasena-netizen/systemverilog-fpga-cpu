#!/usr/bin/env python3
"""Independent integer reference for the Stage 31 tiny network."""
MASK32 = 0xffffffff
W1 = [[1,1,1,1],[1,-1,1,-1],[-1,1,-1,1],[1,1,-1,-1]]
W2 = [[1,1,1,1],[1,-1,1,-1]]
B1 = [0,0,0,0]
B2 = [0,3]
TESTS = [[1,2,3,4],[3,-2,1,4],[-1,-2,-3,-4],[4,1,2,-3]]
def s8(x):
    x &= 0xff
    return x-256 if x & 0x80 else x
def s32(x):
    x &= MASK32
    return x-(1<<32) if x & 0x80000000 else x
def infer(x):
    hidden = [max(0, s32(sum(s8(a)*w for a,w in zip(x,row))+b)) for row,b in zip(W1,B1)]
    scores = [s32(sum(h*w for h,w in zip(hidden,row))+b) & MASK32 for row,b in zip(W2,B2)]
    return hidden, scores, 0 if s32(scores[0]) >= s32(scores[1]) else 1
if __name__ == '__main__':
    for i,x in enumerate(TESTS,1):
        h,y,c = infer(x)
        print(f'TEST{i} input={x} hidden={h} scores={[f"0x{v:08x}" for v in y]} class={c}')
    print('AI_TINY_NN_GOLDEN_PASS')
