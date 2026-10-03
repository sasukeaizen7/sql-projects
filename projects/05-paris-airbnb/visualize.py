"""Charts for the Paris Airbnb project."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
import matplotlib.pyplot as plt  # noqa: E402
import numpy as np  # noqa: E402

from toolkit import Project, style, save, bar_h, PALETTE, INK_2, GRID  # noqa: E402

SOURCE = "Inside Airbnb, Paris listings scraped June 2026, CC BY 4.0"


def arr(n: int) -> str:
    return "1er" if n == 1 else f"{n}e"


def main(p: Project) -> None:
    style()

    a = p.result("price_by_arrondissement")
    fig, ax = plt.subplots(figsize=(8.5, 6.6))
    bar_h(ax, [f"{arr(n)} · {name}" for n, name in zip(a["arrondissement"], a["neighbourhood"])],
          a["median_price"], fmt=lambda v: f"€{v:.0f}")
    ax.set_title("A night in the 8e costs 2.5× a night in the 20e")
    save(fig, p.images / "price_by_arrondissement.png", SOURCE,
         "Median nightly price, entire homes reviewed in the last 12 months")

    h = p.result("host_concentration")
    y = np.arange(len(h))[::-1]
    fig, ax = plt.subplots(figsize=(9, 3.8))
    ax.barh(y + 0.19, h["hosts_pct"], height=0.36, color=PALETTE[0], label="% of hosts")
    ax.barh(y - 0.19, h["listings_pct"], height=0.36, color=PALETTE[1], label="% of listings")
    for yy, a_, b_ in zip(y, h["hosts_pct"], h["listings_pct"]):
        ax.text(a_ + 0.8, yy + 0.19, f"{a_:.1f}%", va="center", fontsize=9, color=INK_2)
        ax.text(b_ + 0.8, yy - 0.19, f"{b_:.1f}%", va="center", fontsize=9, color=INK_2)
    ax.set_yticks(y, [f"Hosts with {x}" for x in h["portfolio"]])
    ax.tick_params(axis="y", length=0)
    ax.grid(axis="y", visible=False)
    ax.set_xlim(0, 100)
    ax.xaxis.set_major_formatter(lambda v, _: f"{v:.0f}%")
    ax.legend(loc="lower right")
    ax.set_title("0.3% of hosts run 14.5% of all Paris listings")
    save(fig, p.images / "host_concentration.png", SOURCE, "Hosts grouped by how many listings they operate")

    lc = p.result("license_compliance")
    fig, ax = plt.subplots(figsize=(9, 4))
    labels = lc["license_status"].str[3:]
    bars = bar_h(ax, labels, lc["pct"], fmt=lambda v: f"{v:.1f}%")
    flagged = {"No license number", "Obvious placeholder (75123456789x)", "Malformed number", "Same number used by several hosts"}
    for b, lab in zip(bars, list(labels)[::-1]):
        b.set_color(PALETTE[7] if lab in flagged else GRID)
    ax.set_title("About 1 entire home in 8 shows no valid registration number")
    save(fig, p.images / "license_compliance.png", SOURCE,
         "Entire homes by registration-number status (red = missing, fake, malformed or shared)")


if __name__ == "__main__":
    main(Project.here(__file__))
