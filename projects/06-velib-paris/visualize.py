"""Charts for the Vélib' project: a station map and fill rate by arrondissement."""

import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
import matplotlib.pyplot as plt  # noqa: E402
import pandas as pd  # noqa: E402
from matplotlib.colors import LinearSegmentedColormap  # noqa: E402

from toolkit import Project, style, save, bar_h, INK, INK_2, SURFACE  # noqa: E402
from toolkit.charts import BLUES  # noqa: E402

SOURCE = "Vélib' Métropole real-time availability, opendata.paris.fr, ODbL"


def snapshot_label(p: Project) -> str:
    ts = pd.Timestamp(p.result("snapshot")["snapshot_at"].iloc[0])
    return ts.strftime("%A %d %B %Y, %H:%M")


def main(p: Project) -> None:
    style()
    when = snapshot_label(p)

    # 1. Map: every active station, colored by how full it is (sequential: empty = light, full = dark).
    s = p.result("station_map")
    fig, ax = plt.subplots(figsize=(10, 8))
    sc = ax.scatter(s["lon"], s["lat"], c=s["fill_rate"], s=6 + s["capacity"] / 3,
                    cmap=LinearSegmentedColormap.from_list("b", BLUES), vmin=0, vmax=1,
                    edgecolors=SURFACE, linewidths=0.4)
    ax.set_aspect(1 / math.cos(math.radians(48.86)))  # equal distances east-west and north-south
    ax.set_xticks([]), ax.set_yticks([])
    ax.grid(False)
    for side in ax.spines.values():
        side.set_visible(False)
    cb = fig.colorbar(sc, ax=ax, fraction=0.03, pad=0.01, format=lambda v, _: f"{v:.0%}")
    cb.outline.set_visible(False)
    cb.ax.tick_params(colors=INK_2, labelsize=8.5)
    cb.set_label("share of docks holding a bike", color=INK_2)
    # Arrondissement labels at the centre of their stations, for orientation (there is no basemap).
    for n, g in s.dropna(subset=["arrondissement"]).groupby("arrondissement"):
        ax.text(g["lon"].mean(), g["lat"].mean(), "1er" if n == 1 else f"{int(n)}e", ha="center", va="center",
                fontsize=9, fontweight="bold", color=INK, bbox=dict(boxstyle="round,pad=0.15", fc=SURFACE, ec="none", alpha=0.75))
    ax.set_title("On a Saturday morning, the 15e and 12e fill up while the north and east run dry")
    save(fig, p.images / "station_map.png", SOURCE, f"All {len(s):,} active Vélib' stations · snapshot of {when} · dot size = docks")

    # 2. Fill rate by arrondissement.
    a = p.result("by_arrondissement").sort_values("fill_pct", ascending=False)
    fig, ax = plt.subplots(figsize=(8.5, 6.4))
    bar_h(ax, ["1er" if n == 1 else f"{n}e" for n in a["arrondissement"]], a["fill_pct"], fmt=lambda v: f"{v:.0f}%")
    ax.set_title("The 15e has 4× more bikes per dock than the 18e")
    save(fig, p.images / "fill_by_arrondissement.png", SOURCE, f"Bikes available / docks, by arrondissement · {when}")


if __name__ == "__main__":
    main(Project.here(__file__))
