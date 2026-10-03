"""Charts for the OpenFlights project."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
import matplotlib.pyplot as plt  # noqa: E402

from toolkit import Project, style, save, bar_h, PALETTE, INK, INK_2, GRID  # noqa: E402

SOURCE = "OpenFlights.org airports, airlines and routes (route data as of June 2014), ODbL"
PARIS = (2.55, 49.01)  # CDG


def main(p: Project) -> None:
    style()

    # 1. "Spider map" of every nonstop destination from Paris (straight lines in lat/lon, no basemap).
    r = p.result("paris_routes").drop_duplicates("destination")
    fig, ax = plt.subplots(figsize=(11, 5.2))
    for _, row in r.iterrows():
        ax.plot([PARIS[0], row["lon"]], [PARIS[1], row["lat"]], color=PALETTE[0], alpha=0.25, linewidth=0.8)
    ax.scatter(r["lon"], r["lat"], s=10, color=PALETTE[0], zorder=3)
    ax.scatter(*PARIS, s=60, color=PALETTE[1], zorder=4)
    ax.annotate("Paris", PARIS, xytext=(6, 6), textcoords="offset points", fontsize=10, fontweight="bold", color=INK)
    ax.set_xlim(-130, 180)
    ax.set_ylim(-40, 72)
    ax.set_aspect("equal")
    ax.set_xticks([]), ax.set_yticks([])
    for s in ax.spines.values():
        s.set_visible(False)
    ax.grid(False)
    ax.set_title(f"From Paris (CDG + Orly), {len(r)} airports are one nonstop flight away")
    save(fig, p.images / "paris_routes.png", SOURCE, "Every nonstop destination from Paris-CDG and Paris-Orly")

    # 2. Hubs: destinations per airport, Paris highlighted.
    h = p.result("hubs")
    fig, ax = plt.subplots(figsize=(9, 5.2))
    bars = bar_h(ax, [f"{c} ({i})" for c, i in zip(h["city"], h["iata"])], h["destinations"], fmt=lambda v: f"{v:.0f}")
    for b, iata in zip(bars, list(h["iata"])[::-1]):
        b.set_color(PALETTE[1] if iata == "CDG" else PALETTE[0])
    ax.set_title("In 2014, Frankfurt, Paris-CDG and Amsterdam had the most nonstop destinations")
    save(fig, p.images / "hubs.png", SOURCE, "Number of distinct nonstop destinations per airport (Paris-CDG in orange)")

    # 3. Reachability (recursive CTE result).
    q = p.result("reach_from_paris")
    labels = ["Nonstop", "1 connection", "2 connections"]
    fig, ax = plt.subplots(figsize=(8.5, 3.4))
    bars = ax.barh(labels[::-1], q["pct_of_network"][::-1], color=PALETTE[0], height=0.6)
    for b, pct, n in zip(bars, q["pct_of_network"][::-1], q["cumulative_airports"][::-1]):
        ax.text(pct + 1, b.get_y() + b.get_height() / 2, f"{pct:.0f}%  ({n:,.0f} airports)", va="center", fontsize=9, color=INK_2)
    ax.set_xlim(0, 115)
    ax.xaxis.set_major_formatter(lambda v, _: f"{v:.0f}%")
    ax.grid(axis="y", visible=False)
    ax.tick_params(axis="y", length=0)
    ax.set_title("With 2 connections, 89% of the world's airports are reachable from Paris")
    save(fig, p.images / "reach_from_paris.png", SOURCE,
         "Share of airports with departures reachable from Paris, computed with a recursive SQL query")


if __name__ == "__main__":
    main(Project.here(__file__))
