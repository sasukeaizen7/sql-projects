"""Charts for the Chicago crimes project."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
import matplotlib.pyplot as plt  # noqa: E402
from matplotlib.colors import LinearSegmentedColormap  # noqa: E402

from toolkit import Project, style, save, bar_h, PALETTE, INK_2  # noqa: E402
from toolkit.charts import BLUES  # noqa: E402

SOURCE = "City of Chicago Data Portal, Crimes - 2001 to Present (2024 records)"
DAYS = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]


def main(p: Project) -> None:
    style()

    # 1. Arrest rate by crime type.
    t = p.result("by_type").sort_values("arrest_pct", ascending=False)
    fig, ax = plt.subplots(figsize=(8.5, 5.2))
    bar_h(ax, [f"{c} ({n / 1000:.0f}k)" for c, n in zip(t["crime_type"], t["crimes"])], t["arrest_pct"], fmt=lambda v: f"{v:.0f}%")
    ax.set_title("96% of narcotics cases end in arrest, against 3% of car thefts")
    save(fig, p.images / "arrest_rate.png", SOURCE, "Share of 2024 crimes with an arrest, 12 most frequent types (count in brackets)")

    # 2. Weekly rhythm heatmap (placeholder 00:00 / 12:00 times excluded in SQL).
    w = p.result("weekly_rhythm").pivot(index="dow", columns="hr", values="avg_crimes")
    fig, ax = plt.subplots(figsize=(11, 4.2))
    im = ax.imshow(w.values, aspect="auto", cmap=LinearSegmentedColormap.from_list("b", BLUES))
    ax.set_yticks(range(7), DAYS)
    ax.set_xticks(range(0, 24, 2), [f"{h:02d}h" for h in range(0, 24, 2)])
    ax.grid(False)
    for s in ax.spines.values():
        s.set_visible(False)
    cb = fig.colorbar(im, ax=ax, fraction=0.025, pad=0.01)
    cb.outline.set_visible(False)
    cb.ax.tick_params(colors=INK_2, labelsize=8.5)
    cb.set_label("avg crimes per hour", color=INK_2)
    ax.set_title("Chicago crime peaks on weekday afternoons and stays high on weekend nights")
    save(fig, p.images / "weekly_rhythm.png", SOURCE,
         "Average crimes per hour, 2024 · only the 66% of reports with a minute-precise time (rounded :00 and placeholder 00:01 excluded)")

    # 3. Seasonality.
    m = p.result("monthly")
    fig, ax = plt.subplots(figsize=(9, 3.8))
    bars = ax.bar(MONTHS, m["crimes"], color=PALETTE[0], width=0.66)
    peak = m["crimes"].idxmax()
    for i, b in enumerate(bars):
        if i != peak:
            b.set_alpha(0.4)
    ax.annotate(f"{m['crimes'].max():,}", (peak, m["crimes"].max()), xytext=(0, 4), textcoords="offset points",
                ha="center", fontsize=9, color=INK_2)
    ax.yaxis.set_major_formatter(lambda v, _: f"{v / 1000:.0f}k")
    ax.grid(axis="x", visible=False)
    ax.set_title("Crime rises in summer: July is 12% above the monthly average")
    save(fig, p.images / "monthly.png", SOURCE, "Crimes recorded per month, 2024")


if __name__ == "__main__":
    main(Project.here(__file__))
