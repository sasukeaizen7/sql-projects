"""Charts for the French first names project."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
import matplotlib.pyplot as plt  # noqa: E402

from toolkit import Project, style, save, bar_h, PALETTE, INK, INK_2  # noqa: E402

SOURCE = "INSEE, Fichier des prénoms 1900-2024 (counts rounded to multiples of 5), via data.gouv.fr, Licence Ouverte"


def main(p: Project) -> None:
    style()

    # 1. Concentration: share of babies given a top-10 name.
    c = p.result("concentration")
    fig, ax = plt.subplots(figsize=(10, 4))
    ax.plot(c["year"], c["top10_share_pct"], color=PALETTE[0])
    for yr in (1900, 2024):
        v = c.loc[c["year"] == yr, "top10_share_pct"].iloc[0]
        ax.annotate(f"{yr}: {v:.0f}%", (yr, v), xytext=(6 if yr == 1900 else -6, 8), textcoords="offset points",
                    ha="left" if yr == 1900 else "right", fontsize=9, color=INK_2)
    ax.set_ylim(0, 50)
    ax.set_xlim(1900, 2024)
    ax.yaxis.set_major_formatter(lambda v, _: f"{v:.0f}%")
    ax.set_title("In 1900, 43% of babies got a top-10 name; in 2024, under 10%")
    save(fig, p.images / "concentration.png", SOURCE,
         "Share of babies given one of that year's 10 most common names (boys and girls ranked separately)")

    # 2. Rise and fall of five iconic names (5 categorical slots in fixed order, labeled at their peak).
    r = p.result("rise_and_fall")
    order = ["Marie", "Jean", "Nathalie", "Kevin", "Gabriel"]
    fig, ax = plt.subplots(figsize=(10, 4.6))
    for name, color in zip(order, PALETTE):
        g = r[r["name"] == name]
        ax.plot(g["year"], g["babies"], color=color, linewidth=1.8, label=name)
        peak = g.loc[g["babies"].idxmax()]
        ax.annotate(f"{name} · {int(peak['year'])}", (peak["year"], peak["babies"]), xytext=(4, 6),
                    textcoords="offset points", fontsize=9, color=INK)
    ax.yaxis.set_major_formatter(lambda v, _: f"{v / 1000:.0f}k")
    ax.set_xlim(1900, 2024)
    ax.legend(loc="upper right")
    ax.set_title("Every generation has its name: Marie, Jean, Nathalie, Kevin, Gabriel")
    save(fig, p.images / "rise_and_fall.png", SOURCE, "Babies given each name per year in France (peak year labeled)")

    # 3. Top 10 names of 2024, boys and girls side by side.
    t = p.result("top_2024")
    fig, axes = plt.subplots(1, 2, figsize=(11, 4.6))
    for ax, (sex, label), color in zip(axes, [("boy", "Boys"), ("girl", "Girls")], PALETTE):
        g = t[t["sex"] == sex]
        bar_h(ax, g["name"], g["babies"], color=color, fmt=lambda v: f"{v:,.0f}")
        ax.text(0, 1.02, label, transform=ax.transAxes, fontsize=11, fontweight="bold", color=INK)
    for ax in axes:  # same scale on both panels so bar lengths compare across sexes
        ax.set_xlim(0, t["babies"].max() * 1.15)
    axes[0].set_title("Gabriel and Louise were France's favorite names in 2024")
    save(fig, p.images / "top_2024.png", SOURCE, "Number of babies given each name in 2024, top 10 by sex")


if __name__ == "__main__":
    main(Project.here(__file__))
