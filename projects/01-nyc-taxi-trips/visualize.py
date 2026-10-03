"""Charts for the NYC taxi project (reads the SQL results in results/)."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
import matplotlib.pyplot as plt  # noqa: E402
from matplotlib.colors import LinearSegmentedColormap  # noqa: E402

from toolkit import Project, style, save, bar_h, PALETTE, INK_2  # noqa: E402
from toolkit.charts import BLUES, THOUSANDS  # noqa: E402

SOURCE = "NYC Taxi & Limousine Commission, Yellow Taxi trips, January 2024"
DAYS = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]


def main(p: Project) -> None:
    style()

    # 1. When are taxis busiest? weekday x hour heatmap (sequential blue = magnitude).
    h = p.result("demand_heatmap").pivot(index="dow", columns="hr", values="avg_trips")
    fig, ax = plt.subplots(figsize=(11, 4.2))
    im = ax.imshow(h.values, aspect="auto", cmap=LinearSegmentedColormap.from_list("blues", BLUES))
    ax.set_yticks(range(7), DAYS)
    ax.set_xticks(range(0, 24, 2), [f"{x:02d}h" for x in range(0, 24, 2)])
    ax.grid(False)
    for s in ax.spines.values():
        s.set_visible(False)
    cb = fig.colorbar(im, ax=ax, fraction=0.025, pad=0.01)
    cb.outline.set_visible(False)
    cb.ax.tick_params(colors=INK_2, labelsize=8.5)
    cb.set_label("avg trips per hour", color=INK_2)
    ax.set_title("Taxi demand peaks on weekday evenings, and late at night on weekends")
    save(fig, p.images / "demand_heatmap.png", SOURCE, "Average number of trips started, by day of week and hour")

    # 2. Revenue by pickup zone.
    z = p.result("top_pickup_zones")
    fig, ax = plt.subplots(figsize=(9, 5))
    bar_h(ax, z["zone"], z["revenue_usd"], fmt=lambda v: f"${v / 1e6:.1f}M")
    ax.set_title("JFK Airport alone brings in more fare revenue than any Manhattan zone")
    save(fig, p.images / "top_pickup_zones.png", SOURCE, "Total amount paid (USD) by pickup zone, top 10")

    # 3. Daily volume with 7-day average.
    d = p.result("daily_trips")
    fig, ax = plt.subplots(figsize=(10, 4))
    ax.bar(d["day"].astype(str).str[5:], d["trips"], color=PALETTE[0], alpha=0.25, width=0.8, label="Daily trips")
    ax.plot(d["day"].astype(str).str[5:], d["trips_7d_avg"], color=PALETTE[0], label="7-day average")
    ax.yaxis.set_major_formatter(THOUSANDS)
    ax.set_xticks(range(0, len(d), 3))
    ax.grid(axis="x", visible=False)
    ax.legend(loc="lower right")
    ax.set_title("Daily taxi trips in January 2024")
    save(fig, p.images / "daily_trips.png", SOURCE, "Trips per day and 7-day moving average (computed with a SQL window function)")


if __name__ == "__main__":
    main(Project.here(__file__))
