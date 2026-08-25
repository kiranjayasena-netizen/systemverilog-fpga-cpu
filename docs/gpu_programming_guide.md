# GPU programming guide

Reset the accelerator, write instructions and vector memory while idle,
set `program_length`, assert `start` for one clock, wait for `done`, then
read memory/register debug state while idle. Programs are bounded by the
16-entry instruction store and 32-entry vector memory. Execution is
in-order; branches, loops, floating point, multiply, and masks are not part
of this release.
