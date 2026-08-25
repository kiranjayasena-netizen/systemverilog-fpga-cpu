"""Run signed-off Stage 27D workloads through the Basys 3 UART contract."""
import argparse, json, time
from pathlib import Path
import serial

ROOT = Path(__file__).resolve().parents[1]
PROGRAMS = {
    "dot4": ("ai_dot4_70_baseline.mem", "ai_dot4_70_dot4acc.mem", [0]),
    "dot64": ("ai_dot64_baseline.mem", "ai_dot64_dot4acc.mem", [0]),
    "matvec": ("ai_matvec_baseline.mem", "ai_matvec_dot4acc.mem", [0, 1]),
    "edge": ("ai_edge_baseline.mem", "ai_edge_dot4acc.mem", [0]),
}
DATA = {
    "dot4": {16: 0x01020304, 17: 0x05060708},
    "dot64": {16: 0x01010101, 17: 0x01010101},
    "matvec": {16: 0x0500807F, 17: 0xFF01FE03, 18: 0x03FE01FF},
    "edge": {16: 0x01017F80, 17: 0x01010101},
}
GOLDEN = {"dot4": [0x46], "dot64": [0x40],
          "matvec": [0x278, 0xFFFFFF11], "edge": [1]}

def cmd(s, op, payload=b"", n=1):
    s.reset_input_buffer(); s.write(bytes([op]) + payload); s.flush()
    out = s.read(n)
    if len(out) != n: raise RuntimeError(f"opcode {op:#x}: short response {out.hex()}")
    # Allow the controller's TX FSM to return to S_IDLE before the next
    # request.  This is separate from CPU execution timing and is not used
    # for any cycle measurement.
    time.sleep(0.010)
    return out

def word(s, op, addr, value):
    payload = bytes([addr & 0xff]) + int(value & 0xffffffff).to_bytes(4, "big")
    if cmd(s, op, payload)[0] != 0: raise RuntimeError(f"write failed {op:#x}@{addr}")

def read_word(s, addr):
    return int.from_bytes(cmd(s, 5, bytes([addr & 0xff]), 4), "big")

def load_program(path):
    return [int(x, 16) for x in path.read_text().split() if x.strip()]

def run_job(s, variant, workload):
    base, opt, outputs = PROGRAMS[workload]
    image = ROOT / "programs" / (opt if variant == "optimized" else base)
    cmd(s, 2)                         # RESET/load mode
    for addr, value in enumerate(load_program(image)):
        word(s, 3, addr, value)
    # Clear the validation data window, then apply the workload image.
    for addr in range(32): word(s, 4, addr, 0)
    for addr, value in DATA[workload].items(): word(s, 4, addr, value)
    if cmd(s, 6)[0] != 0: raise RuntimeError("START rejected")
    deadline = time.monotonic() + 10
    while time.monotonic() < deadline:
        status = cmd(s, 7)[0]
        if status & 2: break
        time.sleep(.002)
    else: raise TimeoutError(f"{workload} did not complete")
    # READ_DATA enters the wrapper's safe host-load/read mode, which resets
    # the core-owned cycle register. Capture READ_CYCLES immediately after
    # DONE, before synchronous result readback, then read the result words.
    cycles = int.from_bytes(cmd(s, 8, n=4), "big")
    values = [read_word(s, a) for a in outputs]
    expected = GOLDEN[workload]
    return {"variant": variant, "workload": workload,
            "result": [f"0x{x:08x}" for x in values],
            "golden": [f"0x{x:08x}" for x in expected],
            "cycles": cycles, "pass": values == expected}

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", default="COM4")
    ap.add_argument("--variant", choices=["baseline", "optimized"], required=True)
    ap.add_argument("--workload", choices=list(PROGRAMS), action="append")
    ap.add_argument("--repeat", type=int, default=1)
    ap.add_argument("--output", type=Path)
    a = ap.parse_args(); jobs = a.workload or list(PROGRAMS)
    rows = []
    with serial.Serial(a.port, 115200, timeout=2) as s:
        if cmd(s, 1)[0] != 0x81: raise RuntimeError("PING failed")
        for _ in range(a.repeat):
            for w in jobs: rows.append(run_job(s, a.variant, w))
    print(json.dumps(rows, indent=2))
    if a.output: a.output.write_text(json.dumps(rows, indent=2) + "\n")
    if not all(r["pass"] for r in rows): raise SystemExit(1)

if __name__ == "__main__": main()
