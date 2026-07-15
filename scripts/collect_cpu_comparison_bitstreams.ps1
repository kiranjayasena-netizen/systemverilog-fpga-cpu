param(
    [string]$OutputRoot = "reports/phase16b_cpu_bitstream_bundle"
)

$ErrorActionPreference = "Stop"

$bitstreamDir = Join-Path $OutputRoot "bitstreams"
New-Item -ItemType Directory -Force -Path $bitstreamDir | Out-Null

$entries = @(
    @{
        Name = "phase07_single_cycle_style_fpga_top"
        Phase = "Phase 7"
        Architecture = "Original single-cycle-style CPU"
        Bitstream = "reports/bitstreams/fpga_top.bit"
        Notes = "LED/debug wrapper; not a 7-seg MIPS counter"
    },
    @{
        Name = "phase08_multicycle"
        Phase = "Phase 8G"
        Architecture = "Separate multi-cycle CPU"
        Bitstream = "reports/phase8g/bitstreams/fpga_top_multicycle.bit"
        Notes = "LED/debug wrapper; slow-enable top"
    },
    @{
        Name = "phase10_bram_multicycle"
        Phase = "Phase 10H"
        Architecture = "BRAM-aware multi-cycle CPU"
        Bitstream = "reports/phase10h/bitstreams/fpga_top_multicycle_bram.bit"
        Notes = "LED/debug wrapper; BRAM inferred"
    },
    @{
        Name = "phase11_bram_prefetch"
        Phase = "Phase 11C"
        Architecture = "BRAM-aware prefetch multi-cycle CPU"
        Bitstream = "reports/phase11c/bitstreams/fpga_top_multicycle_bram_prefetch.bit"
        Notes = "LED/debug wrapper; instruction prefetch variant"
    },
    @{
        Name = "phase11_ctrlopt_prefetch"
        Phase = "Phase 11E"
        Architecture = "Control-flow optimised BRAM prefetch multi-cycle CPU"
        Bitstream = "reports/phase11e/bitstreams/fpga_top_multicycle_bram_prefetch_ctrlopt.bit"
        Notes = "LED/debug wrapper; Phase 11 preferred variant"
    },
    @{
        Name = "phase12_pipeline"
        Phase = "Phase 12"
        Architecture = "Five-stage pipeline"
        Bitstream = "reports/phase12_pipeline/bitstreams/fpga_top_pipeline.bit"
        Notes = "LED/debug wrapper; first full pipeline path"
    },
    @{
        Name = "phase13a_jumpfast_pipeline"
        Phase = "Phase 13A"
        Architecture = "Pipeline with fast JUMP target request"
        Bitstream = "reports/phase13a/bitstreams/fpga_top_pipeline_jumpfast.bit"
        Notes = "LED/debug wrapper; timing-clean Phase 13A path"
    },
    @{
        Name = "phase13b_beq_prefetch_pipeline"
        Phase = "Phase 13B"
        Architecture = "Pipeline with BEQ target prefetch experiment"
        Bitstream = "reports/phase13b/bitstreams/fpga_top_pipeline_branchprefetch.bit"
        Notes = "LED/debug wrapper; experimental branch-prefetch path"
    },
    @{
        Name = "phase13c_timingopt_pipeline"
        Phase = "Phase 13C"
        Architecture = "Timing-optimised pipeline"
        Bitstream = "reports/phase13c_timing/perf_directive_9p100ns/bitstreams/fpga_top_pipeline_timingopt.bit"
        Notes = "LED/debug wrapper; timing-optimised jumpfast path"
    },
    @{
        Name = "phase13d_loadtiming_pipeline"
        Phase = "Phase 13D"
        Architecture = "Load-forwarding timing experiment"
        Bitstream = "reports/phase13d_timing/perf_directive_9p100ns/bitstreams/fpga_top_pipeline_loadtiming.bit"
        Notes = "LED/debug wrapper; functionally correct but not preferred"
    },
    @{
        Name = "phase13e_13i_forwardtiming_pipeline"
        Phase = "Phase 13E/13I"
        Architecture = "Preferred Phase 13 forwarding-timing pipeline"
        Bitstream = "reports/phase13i_strategy/fanout_opt_8p650ns/bitstreams/fpga_top_pipeline_forwardtiming.bit"
        Notes = "LED/debug wrapper; best Phase 13 implementation strategy result"
    },
    @{
        Name = "phase13f_targetbuf_pipeline_experimental"
        Phase = "Phase 13F"
        Architecture = "Target-buffer pipeline experiment"
        Bitstream = "reports/phase13f_timing/perf_directive_8p900ns/bitstreams/fpga_top_pipeline_targetbuf.bit"
        Notes = "Experimental; timing failed at the recorded 8.900 ns constraint"
    },
    @{
        Name = "phase13g_registered_targetbuf_pipeline"
        Phase = "Phase 13G"
        Architecture = "Registered target-buffer pipeline experiment"
        Bitstream = "reports/phase13g_timing/perf_directive_8p900ns/bitstreams/fpga_top_pipeline_targetbuf_reg.bit"
        Notes = "LED/debug wrapper; timing-clean but not better than Phase 13E"
    },
    @{
        Name = "phase14g_pipeline6"
        Phase = "Phase 14G"
        Architecture = "Six-stage pipeline"
        Bitstream = "reports/phase14g_impl/fanout_opt_6p000ns/bitstreams/fpga_top_pipeline6.bit"
        Notes = "LED/debug wrapper; current best timing/performance evidence"
    },
    @{
        Name = "phase15b_pipeline6_bringup_sticky_leds"
        Phase = "Phase 15B"
        Architecture = "Six-stage pipeline bring-up wrapper"
        Bitstream = "reports/phase15a_bringup_impl/bitstreams/fpga_top_pipeline6_bringup.bit"
        Notes = "Slow-enable/sticky LED hardware evidence wrapper"
    },
    @{
        Name = "phase16a_pipeline6_perf7seg"
        Phase = "Phase 16A"
        Architecture = "Six-stage pipeline hardware MIPS counter"
        Bitstream = "reports/phase16a_perf7seg_impl/bitstreams/fpga_top_pipeline6_perf7seg.bit"
        Notes = "7-seg retired-instruction MIPS counter; board measured about 63 MIPS"
    }
)

$manifest = foreach ($entry in $entries) {
    $source = $entry.Bitstream
    $destFile = Join-Path $bitstreamDir ($entry.Name + ".bit")
    $exists = Test-Path $source

    if ($exists) {
        Copy-Item -LiteralPath $source -Destination $destFile -Force
    }

    [pscustomobject]@{
        Name = $entry.Name
        Phase = $entry.Phase
        Architecture = $entry.Architecture
        Source = $source
        BundlePath = if ($exists) { $destFile } else { "" }
        Status = if ($exists) { "copied" } else { "missing" }
        Notes = $entry.Notes
    }
}

$manifestPath = Join-Path $OutputRoot "manifest.csv"
$manifest | Export-Csv -Path $manifestPath -NoTypeInformation

Write-Host "CPU comparison bitstream bundle:"
Write-Host "  Output:   $OutputRoot"
Write-Host "  Manifest: $manifestPath"
Write-Host ""
$manifest | Format-Table Phase, Name, Status, BundlePath -AutoSize
