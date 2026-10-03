"""Charts for the earthquakes project: world map, Gutenberg-Richter law, M7+ per year."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
import matplotlib.pyplot as plt  # noqa: E402
import numpy as np  # noqa: E402
from matplotlib.colors import LinearSegmentedColormap  # noqa: E402

from toolkit import Project, style, save, PALETTE, INK_2, SURFACE  # noqa: E402
from toolkit.charts import BLUES  # noqa: E402

SOURCE = "USGS Earthquake Hazards Program, ComCat catalog (public domain), 2000-2025"


def main(p: Project) -> None:
    style()

    # 1. Map of M6+ quakes: position only (no basemap); plate boundaries appear on their own.
    m = p.result("map_points")
    fig, ax = plt.subplots(figsize=(11, 4.6))
    sc = ax.scatter(m["longitude"], m["latitude"], s=(m["mag"] - 5.5) ** 3 * 6, c=m["depth_km"].clip(upper=700),
                    cmap=LinearSegmentedColormap.from_list("b", BLUES[1:]), edgecolors=SURFACE, linewidths=0.3, alpha=0.9)
    ax.set_xlim(-180, 180)
    ax.set_ylim(-70, 80)
    ax.set_aspect("equal")
    ax.set_xticks(range(-180, 181, 60), [f"{x}°" for x in range(-180, 181, 60)])
    ax.set_yticks(range(-60, 81, 30), [f"{y}°" for y in range(-60, 81, 30)])
    cb = fig.colorbar(sc, ax=ax, fraction=0.02, pad=0.01)
    cb.outline.set_visible(False)
    cb.ax.tick_params(colors=INK_2, labelsize=8.5)
    cb.set_label("depth (km)", color=INK_2)
    cb.ax.invert_yaxis()
    ax.set_title(f"{len(m):,} earthquakes of magnitude 6+ trace the edges of the tectonic plates")
    save(fig, p.images / "world_map.png", SOURCE, "Every M6+ earthquake 2000-2025 · dot size = magnitude · color = depth")

    # 2. Gutenberg-Richter: log-linear frequency-magnitude law with the SQL-fitted line.
    g = p.result("gutenberg_richter")
    b = p.result("b_value").iloc[0]
    fig, ax = plt.subplots(figsize=(9, 4.6))
    ax.scatter(g["magnitude"], g["events_at_or_above"], color=PALETTE[0], s=22, zorder=3, label="Observed (cumulative)")
    xs = np.linspace(5.0, 9.1, 50)
    ax.plot(xs, 10 ** (b["a_value"] - b["b_value"] * xs), color=PALETTE[1], linewidth=1.5,
            label=f"Fit: log₁₀N = {b['a_value']:.2f} − {b['b_value']:.2f}·M  (R² = {b['r2']:.3f})")
    ax.set_yscale("log")
    ax.set_xlabel("Magnitude M")
    ax.set_ylabel("Earthquakes with magnitude ≥ M")
    ax.yaxis.set_major_formatter(lambda v, _: f"{v:,.0f}")
    ax.legend(loc="upper right")
    ax.set_title("Each extra unit of magnitude is about 10× rarer (Gutenberg-Richter law, b ≈ 1.02)")
    save(fig, p.images / "gutenberg_richter.png", SOURCE, "Number of earthquakes at or above each magnitude, log scale, 2000-2025")

    # 3. M7+ per year.
    y = p.result("per_year")
    fig, ax = plt.subplots(figsize=(10, 3.8))
    ax.bar(y["year"], y["m7_plus"], color=PALETTE[0], width=0.7)
    avg = y["m7_plus"].mean()
    ax.axhline(avg, color=INK_2, linewidth=1)
    ax.annotate(f"average {avg:.1f} per year", (y["year"].iloc[-1] + 0.5, avg), xytext=(4, 4), textcoords="offset points",
                fontsize=9, color=INK_2, ha="right", va="bottom")
    ax.grid(axis="x", visible=False)
    ax.set_title("About 15 major (M7+) earthquakes a year, with no upward trend")
    save(fig, p.images / "m7_per_year.png", SOURCE, "Number of earthquakes of magnitude 7 or more per year")


if __name__ == "__main__":
    main(Project.here(__file__))
