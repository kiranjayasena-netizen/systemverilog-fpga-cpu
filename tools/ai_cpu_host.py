"""Host utility for the Stage 27C validation tops (115200 8-N-1).

Words are sent big-endian.  The utility intentionally contains no benchmark
timing assumptions; READ_CYCLES is the CPU-only counter returned by hardware.
"""
import argparse, time
import serial

def open_port(name): return serial.Serial(name, 115200, timeout=2)
def command(s, op, payload=b"", n=1):
    s.reset_input_buffer(); s.write(bytes([op])+payload); s.flush()
    b=s.read(n)
    if len(b)!=n: raise RuntimeError(f"short response for {op:#x}: {b.hex()}")
    return b
def write_instr(s,a,w): command(s,3,bytes([a,(w>>24)&255,(w>>16)&255,(w>>8)&255,w&255]))
def write_data(s,a,w): command(s,4,bytes([a])+int(w,16).to_bytes(4,'big'))
def read_data(s,a): return command(s,5,bytes([a]),4).hex()
def wait_done(s):
    for _ in range(100000):
        st=command(s,7)[0]
        if st & 2: return
        time.sleep(.001)
    raise TimeoutError("CPU did not complete")
def main():
    p=argparse.ArgumentParser(); p.add_argument('--port',required=True)
    p.add_argument('--ping',action='store_true'); p.add_argument('--reset',action='store_true')
    p.add_argument('--status',action='store_true'); p.add_argument('--write-instr',nargs=2)
    p.add_argument('--write-data',nargs=2); p.add_argument('--read-data',type=int)
    p.add_argument('--read-cycles',action='store_true'); p.add_argument('--start',action='store_true')
    a=p.parse_args(); s=open_port(a.port)
    try:
        if a.ping: print(command(s,1).hex())
        if a.reset: print('reset',command(s,2).hex())
        if a.write_instr: write_instr(s,int(a.write_instr[0],0),int(a.write_instr[1],0)); print('write-instr PASS')
        if a.write_data: write_data(s,int(a.write_data[0],0),a.write_data[1]); print('write-data PASS')
        if a.read_data is not None: print(f"read-data {a.read_data}={read_data(s,a.read_data)}")
        if a.start: print('start',command(s,6).hex()); wait_done(s)
        if a.status: print('status',command(s,7).hex())
        if a.read_cycles: print('cycles',int.from_bytes(command(s,8, n=4),'big'))
    finally: s.close()
if __name__=='__main__': main()
