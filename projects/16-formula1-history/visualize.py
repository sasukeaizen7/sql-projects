"""Charts for the Formula 1 project."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
import matplotlib.pyplot as plt  # noqa: E402

from toolkit import Project, style, save, bar_h, PALETTE, INK_2  # noqa: E402

SOURCE = "F1DB, the open Formula 1 database (f1db/f1db), CC BY 4.0"


def column_labels(ax, bars, values, fmt):
    for b, v in zip(bars, values):
        ax.text(b.get_x() + b.get_width() / 2, b.get_height() + 1, fmt(v), ha="center", fontsize=9, color=INK_2)


def main(p: Project) -> None:
    style()

    r = p.result("reliability")
    fig, ax = plt.subplots(figsize=(9, 4))
    bars = ax.bar([f"{d}s" for d in r["decade"]], r["finished_pct"], color=PALETTE[0], width=0.66)
    column_labels(ax, bars, r["finished_pct"], lambda v: f"{v:.0f}%")
    ax.set_ylim(0, 100)
    ax.yaxis.set_major_formatter(lambda v, _: f"{v:.0f}%")
    ax.grid(axis="x", visible=False)
    ax.set_title("In the 1980s most cars failed to finish; today 87% do")
    save(fig, p.images / "reliability.png", SOURCE, "Share of starters classified at the finish, by decade (2020s = 2020-2026)")

    g = p.result("grid_to_win")
    fig, ax = plt.subplots(figsize=(9, 4))
    bars = ax.bar([f"P{x}" for x in g["grid_position"]], g["share_of_all_wins_pct"], color=PALETTE[0], width=0.66)
    column_labels(ax, bars, g["share_of_all_wins_pct"], lambda v: f"{v:.0f}%")
    ax.yaxis.set_major_formatter(lambda v, _: f"{v:.0f}%")
    ax.grid(axis="x", visible=False)
    ax.set_xlabel("Starting position")
    ax.set_title("Pole position wins 44% of all races, and the front row two-thirds")
    save(fig, p.images / "grid_to_win.png", SOURCE, "Share of all Grand Prix wins since 1950 by starting grid position")

    d = p.result("dominant_seasons")
    fig, ax = plt.subplots(figsize=(9, 5))
    bar_h(ax, [f"{y} · {n} ({w}/{t})" for y, n, w, t in zip(d["year"], d["name"], d["wins"], d["races"])],
          d["win_share_pct"], fmt=lambda v: f"{v:.0f}%")
    ax.set_title("Verstappen's 2023 is the most dominant season ever: 19 wins in 22 races")
    save(fig, p.images / "dominant_seasons.png", SOURCE, "Share of a season's races won by a single driver, top 10 (complete seasons 1950-2025)")


if __name__ == "__main__":
    main(Project.here(__file__))
