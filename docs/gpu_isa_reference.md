# GPU ISA reference

Instructions are 16 bits. The existing decoder supports VADD, VSUB, VAND,
VOR, VXOR, VCMPEQ, VCMPLT, VSLL, VSRL, VSRA, VLOAD and VSTORE. ALU
instructions encode operation, destination, and two source registers.
VLOAD encodes a destination register and 5-bit vector-memory address;
VSTORE encodes a source register and 5-bit address. Lane 0 is bits [31:0]
of a vector and lane 3 is bits [127:96].
