#!/usr/bin/env python3
"""Host utility for the Basys 3 GPU UART protocol."""
import argparse, time
try:
    import serial
except ImportError:
    serial = None

def open_port(name, baud):
    if serial is None:
        raise SystemExit("pyserial is required: python -m pip install pyserial")
    return serial.Serial(name, baudrate=baud, timeout=1)

def tx(ser, payload):
    ser.write(bytes(payload))

def rx_exact(ser, count):
    data = ser.read(count)
    if len(data) != count:
        raise RuntimeError(f"UART timeout: expected {count} bytes, received {len(data)}")
    return data

def ping(ser):
    tx(ser, [0x01]); return rx_exact(ser, 1)[0]

def status(ser):
    tx(ser, [0x07]); return rx_exact(ser, 1)[0]

def reset_gpu(ser):
    tx(ser, [0x02]); time.sleep(0.01)

def write_instr(ser, addr, word):
    if not 0 <= addr <= 15 or not 0 <= word <= 0xffff:
        raise ValueError("instruction address/word out of range")
    tx(ser, [0x03, addr, (word >> 8) & 0xff, word & 0xff])

def set_length(ser, length):
    if not 0 <= length <= 31: raise ValueError("program length must be 0..31")
    tx(ser, [0x04, length & 0x1f])

def write_memory(ser, addr, value):
    if not 0 <= addr <= 31 or not 0 <= value < (1 << 128):
        raise ValueError("memory address/value out of range")
    tx(ser, [0x05, addr] + list(value.to_bytes(16, "little")))

def read_memory(ser, addr):
    if not 0 <= addr <= 31: raise ValueError("memory address must be 0..31")
    tx(ser, [0x08, addr])
    first = rx_exact(ser, 1)
    if first == b"\xe1": raise RuntimeError("GPU busy")
    response = first + rx_exact(ser, 15)
    return int.from_bytes(response, "little")

def run_until_done(ser, timeout=10):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        st = status(ser)
        if st & 0x02: return
        time.sleep(0.01)
    raise RuntimeError("timeout waiting for GPU DONE")

def alu(op, dst, a, b): return ((op & 0xf) << 12) | ((dst & 7) << 9) | ((a & 7) << 6) | ((b & 7) << 3)
def vload(dst, addr): return 0xa000 | ((dst & 7) << 9) | ((addr & 31) << 4)
def vstore(src, addr): return 0xb000 | ((src & 7) << 9) | ((addr & 31) << 4)

def execute(ser, program, memory, outputs):
    reset_gpu(ser)
    for addr, word in enumerate(program): write_instr(ser, addr, word)
    set_length(ser, len(program))
    for addr, value in memory.items(): write_memory(ser, addr, value)
    tx(ser, [0x06]); run_until_done(ser)
    for addr, expected in outputs.items():
        actual = read_memory(ser, addr)
        if actual != expected: raise RuntimeError(f"memory[{addr}] expected {expected:032x} got {actual:032x}")

def demo(ser, name):
    if name == "reg_vadd":
        # RF reset values are zero; this validates the complete control path
        # and four in-order ALU instructions through the production wrapper.
        program = [alu(0,3,1,2), alu(0,4,3,2), alu(0,5,4,2), alu(0,6,5,2)]
        execute(ser, program, {}, {})
    elif name == "array_add":
        mem = {}; out = {}
        for i in range(4):
            a = [i+1,i+2,i+3,i+4]; b = [10+i,20+i,30+i,40+i]
            mem[i] = int.from_bytes(b''.join(x.to_bytes(4,'little') for x in a), 'little')
            mem[8+i] = int.from_bytes(b''.join(x.to_bytes(4,'little') for x in b), 'little')
            result = [a[j]+b[j] for j in range(4)]
            out[16+i] = int.from_bytes(b''.join(x.to_bytes(4,'little') for x in result), 'little')
        program=[]
        for i in range(4): program += [vload(1,i), vload(2,8+i), alu(0,3,1,2), vstore(3,16+i)]
        execute(ser, program, mem, out)
    elif name in ("xor", "vsra"):
        op = 4 if name == "xor" else 9; mem={}; out={}; program=[]
        for i in range(4):
            vals = [i,i+1,i+2,i+3] if name == "xor" else [0x80000000+i,1,0xffffffff,0x7fffffff]
            value = int.from_bytes(b''.join(x.to_bytes(4,'little') for x in vals), 'little'); mem[i]=value
            # V2 is reset to zero in the host-programmable integration.
            out[16+i] = value if name == "xor" else value
            program += [vload(1,i), alu(op,3,1,2), vstore(3,16+i)]
        execute(ser, program, mem, out)
    else: raise ValueError(name)
    print(f"DEMO {name.upper()} PASS")

def main():
    ap=argparse.ArgumentParser(); ap.add_argument('--port',required=True); ap.add_argument('--baud',type=int,default=115200)
    ap.add_argument('--ping',action='store_true'); ap.add_argument('--reset',action='store_true'); ap.add_argument('--start',action='store_true')
    ap.add_argument('--status',action='store_true'); ap.add_argument('--length',type=int); ap.add_argument('--repeat',type=int,default=1)
    ap.add_argument('--write-instr',nargs=2,metavar=('ADDR','WORD')); ap.add_argument('--write-memory',nargs=2,metavar=('ADDR','HEX128'))
    ap.add_argument('--read-memory',type=int); ap.add_argument('--demo',choices=['reg_vadd','array_add','xor','vsra']); ap.add_argument('--run-all-demos',action='store_true')
    args=ap.parse_args()
    with open_port(args.port,args.baud) as ser:
        for i in range(max(1,args.repeat)):
            if args.reset: reset_gpu(ser)
            if args.ping: print(f"PING iteration={i+1} response={ping(ser):02x}")
            if args.write_instr: write_instr(ser,int(args.write_instr[0],0),int(args.write_instr[1],16))
            if args.write_memory: write_memory(ser,int(args.write_memory[0],0),int(args.write_memory[1],16))
            if args.read_memory is not None: print(f"READ_MEMORY addr={args.read_memory} data={read_memory(ser,args.read_memory):032x}")
            if args.length is not None: set_length(ser,args.length)
            if args.start: tx(ser,[0x06]); run_until_done(ser); print(f"DONE iteration={i+1}")
            if args.status: print(f"STATUS iteration={i+1} response={status(ser):02x}")
            if args.demo: demo(ser,args.demo)
            if args.run_all_demos:
                for name in ('reg_vadd','array_add','xor','vsra'): demo(ser,name)
if __name__ == '__main__': main()
