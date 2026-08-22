#!/usr/bin/env python3
"""Minimal host utility for the Stage 14 Basys 3 UART protocol."""
import argparse, time

try:
    import serial
except ImportError:
    serial = None

def open_port(name, baud):
    if serial is None:
        raise SystemExit("pyserial is required: python -m pip install pyserial")
    return serial.Serial(name, baudrate=baud, timeout=1)

def send(ser, payload, response=False):
    ser.write(bytes(payload))
    return ser.read(1) if response else b""

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", required=True)
    ap.add_argument("--baud", type=int, default=115200)
    ap.add_argument("--ping", action="store_true")
    ap.add_argument("--reset", action="store_true")
    ap.add_argument("--start", action="store_true")
    ap.add_argument("--status", action="store_true")
    ap.add_argument("--length", type=int)
    ap.add_argument("--repeat", type=int, default=1)
    args = ap.parse_args()
    with open_port(args.port, args.baud) as ser:
        for index in range(max(1, args.repeat)):
            if args.reset:
                send(ser, [0x02])
            if args.ping:
                response = send(ser, [0x01], True)
                print(f"PING iteration={index+1} response={response.hex()}")
            if args.length is not None:
                if not 0 <= args.length <= 31:
                    raise SystemExit("--length must be in the range 0..31")
                send(ser, [0x04, args.length & 0x1f])
            if args.start:
                send(ser, [0x06])
            if args.status:
                response = send(ser, [0x07], True)
                print(f"STATUS iteration={index+1} response={response.hex()}")
            if args.start:
                deadline = time.monotonic() + 10.0
                while time.monotonic() < deadline:
                    status = send(ser, [0x07], True)
                    if status and (status[0] & 0x02):
                        print(f"DONE iteration={index+1}")
                        break
                    time.sleep(0.01)
                else:
                    raise SystemExit(f"timeout waiting for DONE at iteration {index+1}")

if __name__ == "__main__":
    main()
