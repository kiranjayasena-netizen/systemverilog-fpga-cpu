"""Generate dependency-free SVG charts from the committed Stage E CSV."""

from __future__ import annotations

import csv
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CSV_PATH = ROOT / "reports" / "dot4acc_stage_e" / "results.csv"
OUT_DIR = CSV_PATH.parent
COLORS = {"Scalar": "#4c78a8", "MAC8": "#f58518", "DOT4ACC": "#54a24b"}


def load_scaling_rows() -> list[dict[str, str]]:
    with CSV_PATH.open(newline="", encoding="utf-8") as handle:
        rows = list(csv.DictReader(handle))
    return [row for row in rows if row["benchmark"] in {"packed4", "vector_scaling"}]


def write_line_chart(
    filename: str,
    title: str,
    y_label: str,
    field: str,
    implementations: tuple[str, ...] = ("Scalar", "MAC8", "DOT4ACC"),
) -> None:
    rows = load_scaling_rows()
    lengths = sorted({int(row["vector_length"]) for row in rows})
    series = {
        impl: [
            float(next(row[field] for row in rows
                       if row["implementation"] == impl and int(row["vector_length"]) == length))
            for length in lengths
        ]
        for impl in implementations
    }
    width, height = 760, 430
    left, right, top, bottom = 78, 24, 46, 62
    plot_w, plot_h = width - left - right, height - top - bottom
    maximum = max(max(values) for values in series.values())
    y_max = maximum * 1.10 if maximum else 1.0

    def x_pos(index: int) -> float:
        return left + (plot_w * index / (len(lengths) - 1))

    def y_pos(value: float) -> float:
        return top + plot_h * (1.0 - value / y_max)

    parts = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">',
        '<rect width="100%" height="100%" fill="white"/>',
        f'<text x="{width/2}" y="26" text-anchor="middle" font-family="sans-serif" font-size="18">{title}</text>',
        f'<line x1="{left}" y1="{top}" x2="{left}" y2="{top+plot_h}" stroke="#333"/>',
        f'<line x1="{left}" y1="{top+plot_h}" x2="{left+plot_w}" y2="{top+plot_h}" stroke="#333"/>',
        f'<text x="18" y="{top+plot_h/2}" transform="rotate(-90 18 {top+plot_h/2})" text-anchor="middle" font-family="sans-serif" font-size="13">{y_label}</text>',
        f'<text x="{left+plot_w/2}" y="{height-14}" text-anchor="middle" font-family="sans-serif" font-size="13">Vector length (useful INT8 MACs)</text>',
    ]
    for tick in range(6):
        value = y_max * tick / 5
        y = y_pos(value)
        parts.append(f'<line x1="{left}" y1="{y:.1f}" x2="{left+plot_w}" y2="{y:.1f}" stroke="#ddd"/>')
        parts.append(f'<text x="{left-8}" y="{y+4:.1f}" text-anchor="end" font-family="sans-serif" font-size="11">{value:.1f}</text>')
    for index, length in enumerate(lengths):
        x = x_pos(index)
        parts.append(f'<text x="{x:.1f}" y="{top+plot_h+20}" text-anchor="middle" font-family="sans-serif" font-size="11">{length}</text>')
    for legend_index, impl in enumerate(implementations):
        points = " ".join(f"{x_pos(i):.1f},{y_pos(value):.1f}" for i, value in enumerate(series[impl]))
        color = COLORS[impl]
        parts.append(f'<polyline points="{points}" fill="none" stroke="{color}" stroke-width="2.5"/>')
        for i, value in enumerate(series[impl]):
            parts.append(f'<circle cx="{x_pos(i):.1f}" cy="{y_pos(value):.1f}" r="3.5" fill="{color}"/>')
        lx = left + 12 + legend_index * 122
        parts.append(f'<line x1="{lx}" y1="{top+12}" x2="{lx+22}" y2="{top+12}" stroke="{color}" stroke-width="3"/>')
        parts.append(f'<text x="{lx+28}" y="{top+16}" font-family="sans-serif" font-size="12">{impl}</text>')
    parts.append("</svg>")
    (OUT_DIR / filename).write_text("\n".join(parts) + "\n", encoding="utf-8")


def main() -> None:
    write_line_chart("cycles_vs_vector_length.svg", "Stage E cycles through final STORE", "Enabled cycles", "cycles_to_store")
    write_line_chart("retired_vs_vector_length.svg", "Stage E retired instructions", "Retired instructions", "retired_instructions")
    write_line_chart("mmac_vs_vector_length.svg", "Stage E effective throughput at 100 MHz", "MMAC/s", "mmac_per_s_100mhz")
    write_line_chart("speedup_vs_vector_length.svg", "Stage E speedup versus scalar", "Speedup (x)", "speedup_vs_scalar")
    write_line_chart("dot_peak_utilisation.svg", "DOT arithmetic peak utilisation", "Percent of 400 MMAC/s", "dot_peak_utilisation_percent", ("DOT4ACC",))
    print(f"Generated Stage E SVG charts in {OUT_DIR}")


if __name__ == "__main__":
    main()
