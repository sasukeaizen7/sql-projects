"""Charts for the RATP traffic project."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
import matplotlib.pyplot as plt  # noqa: E402
import numpy as np  # noqa: E402

from toolkit import Project, style, save, bar_h, PALETTE, INK_2, GRID  # noqa: E402

SOURCE = "RATP Open Data, Trafic annuel entrant par station du réseau ferré 2013-2021"


def main(p: Project) -> None:
    style()

    # 1. Yearly entries by network, same unit on one axis.
    y = p.result("yearly")
    fig, ax = plt.subplots(figsize=(10, 4.4))
    for i, (net, g) in enumerate(y.groupby("network", sort=False)):
        ax.plot(g["year"], g["entries"] / 1e9, color=PALETTE[i], marker="o", markersize=5, label=net)
        ax.annotate(f"{net}: {g['entries'].iloc[-1] / 1e9:.2f}B", (g["year"].iloc[-1], g["entries"].iloc[-1] / 1e9),
                    xytext=(8, 0), textcoords="offset points", va="center", fontsize=9, color=INK_2)
    m20 = y[(y["network"] == "Métro") & (y["year"] == 2020)].iloc[0]
    ax.annotate(f"COVID: {m20['yoy_pct']:.0f}%", (2020, m20["entries"] / 1e9), xytext=(10, -14),
                textcoords="offset points", fontsize=9, color=INK_2)
    ax.set_ylim(0, 1.6)
    ax.set_xlim(2012.6, 2021.9)
    ax.yaxis.set_major_formatter(lambda v, _: f"{v:.1f}B")
    ax.legend(loc="lower left")
    ax.set_title("COVID halved Métro and RER traffic in 2020; 2021 was still a third below 2019")
    save(fig, p.images / "yearly_traffic.png", SOURCE, "Annual entries (billions) on the RATP Métro and RER networks")

    # 2. Top stations: 2019 vs 2021 (grouped bars, same unit).
    t = p.result("top_stations")
    names = [s.title().replace("-Rer", " (RER)") for s in t["station"]]
    yy = np.arange(len(t))[::-1]
    fig, ax = plt.subplots(figsize=(9.5, 5.6))
    ax.barh(yy + 0.19, t["entries_2019"] / 1e6, height=0.36, color=PALETTE[0], label="2019")
    ax.barh(yy - 0.19, t["entries_2021"] / 1e6, height=0.36, color=PALETTE[1], label="2021")
    for y0, v19, v21, pct in zip(yy, t["entries_2019"] / 1e6, t["entries_2021"] / 1e6, t["recovery_2021_pct"]):
        ax.text(v19 + 0.6, y0 + 0.19, f"{v19:.1f}M", va="center", fontsize=8.5, color=INK_2)
        ax.text(v21 + 0.6, y0 - 0.19, f"{v21:.1f}M ({pct:.0f}% of 2019)", va="center", fontsize=8.5, color=INK_2)
    ax.set_yticks(yy, names)
    ax.tick_params(axis="y", length=0)
    ax.grid(axis="y", visible=False)
    ax.set_xlim(0, t["entries_2019"].max() / 1e6 * 1.3)
    ax.xaxis.set_major_formatter(lambda v, _: f"{v:.0f}M")
    ax.legend(loc="lower right")
    ax.set_title("La Défense recovered least among the 10 busiest stations: 52% of 2019")
    save(fig, p.images / "top_stations.png", SOURCE, "Annual entries at the 10 busiest stations of 2019")

    # 3. Recovery by arrondissement, like-for-like stations; suburbs highlighted.
    r = p.result("recovery_by_area").sort_values("recovery_pct", ascending=False)
    labels = ["Suburbs" if a == "Suburbs" else ("1er" if a == "1" else f"{a}e") for a in r["area"]]
    fig, ax = plt.subplots(figsize=(8.5, 6.6))
    bars = bar_h(ax, labels, r["recovery_pct"], fmt=lambda v: f"{v:.0f}%")
    for b, lab in zip(bars, labels[::-1]):
        if lab == "Suburbs":
            b.set_color(PALETTE[1])
    ax.set_title("Residential east Paris came back faster than the business districts")
    save(fig, p.images / "recovery_by_area.png", SOURCE,
         "Métro entries in 2021 as % of 2019, stations open in both years (suburbs in orange)")


if __name__ == "__main__":
    main(Project.here(__file__))
