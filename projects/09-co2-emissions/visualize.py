"""Charts for the CO2 emissions project."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
import matplotlib.pyplot as plt  # noqa: E402

from toolkit import Project, style, save, bar_h, PALETTE, INK_2, SURFACE  # noqa: E402
from toolkit.charts import DIVERGING  # noqa: E402

SOURCE = "Our World in Data, CO2 and Greenhouse Gas Emissions dataset (Global Carbon Project), CC BY 4.0"


def main(p: Project) -> None:
    style()

    # 1. Top emitters 2024.
    t = p.result("top_emitters_2024")
    fig, ax = plt.subplots(figsize=(8.5, 4.8))
    bar_h(ax, t["country"], t["co2_mt"], fmt=lambda v: f"{v:,.0f} Mt")
    ax.set_title("China emits more CO₂ than the US, India and Russia combined")
    save(fig, p.images / "top_emitters_2024.png", SOURCE, "Territorial CO₂ emissions in 2024, million tonnes")

    # 2. Change since 2005: diverging (blue = fell, red = rose), gray zero line.
    c = p.result("change_since_2005")
    fig, ax = plt.subplots(figsize=(8.5, 5.6))
    vals = list(c["change_pct"])[::-1]
    labels = list(c["country"])[::-1]
    ax.barh(labels, vals, color=[DIVERGING[0] if v < 0 else DIVERGING[2] for v in vals], height=0.68)
    for y, v in enumerate(vals):
        ax.text(v + (3 if v >= 0 else -3), y, f"{v:+.1f}%" if abs(v) < 1 else f"{v:+.0f}%", va="center", ha="left" if v >= 0 else "right", fontsize=9, color=INK_2)
    ax.axvline(0, color=INK_2, linewidth=0.8)
    ax.set_xlim(min(vals) - 25, max(vals) + 30)
    ax.xaxis.set_major_formatter(lambda v, _: f"{v:+.0f}%")
    ax.grid(axis="y", visible=False)
    ax.tick_params(axis="y", length=0)
    ax.set_title("Since 2005, Germany, Japan and the US cut emissions; China, India and Indonesia doubled theirs")
    save(fig, p.images / "change_since_2005.png", SOURCE, "Change in CO₂ emissions 2005 → 2024, 15 largest emitters of 2024")

    # 3. World emissions by fuel (stacked area, 4 categorical slots in fixed order, labeled at the end).
    w = p.result("world_by_fuel")
    series = [("Coal", "coal_gt"), ("Oil", "oil_gt"), ("Gas", "gas_gt"), ("Cement", "cement_gt")]
    fig, ax = plt.subplots(figsize=(10, 4.8))
    ax.stackplot(w["year"], *[w[col] for _, col in series], labels=[n for n, _ in series],
                 colors=PALETTE[:4], edgecolor=SURFACE, linewidth=1)
    bottom = 0
    for (name, col), color in zip(series, PALETTE):
        v = w[col].iloc[-1]
        ax.annotate(f"{name} {v:.1f} Gt", (w["year"].iloc[-1], bottom + v / 2), xytext=(8, 0),
                    textcoords="offset points", va="center", fontsize=9, color=INK_2)
        bottom += v
    ax.set_xlim(1900, 2024)
    ax.yaxis.set_major_formatter(lambda v, _: f"{v:.0f} Gt")
    ax.legend(loc="upper left")
    ax.set_title("World CO₂ emissions keep rising, and coal is still the biggest source")
    save(fig, p.images / "world_by_fuel.png", SOURCE, "Global fossil and cement CO₂ emissions by source, billion tonnes")


if __name__ == "__main__":
    main(Project.here(__file__))
