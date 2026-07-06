# Reports

This directory is for selected Vivado text reports from synthesis and implementation.

Expected generated reports include:

- `reports/utilisation/*_utilization.rpt`
- `reports/timing/*_timing_summary.rpt`
- `reports/power/*_power.rpt`

Vivado checkpoints, bitstreams, databases, logs and generated run directories should normally stay uncommitted. The repository `.gitignore` already excludes common generated files such as `.dcp`, `.bit`, `.jou`, `.log`, `.wdb`, `.vcd` and `xsim.dir/`.

Commit only small text reports that are useful for project documentation or supervisor review.
