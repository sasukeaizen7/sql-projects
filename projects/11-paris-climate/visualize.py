"""Charts for the Paris climate project: warming stripes, hot days, monthly warming."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
import matplotlib.pyplot as plt  # noqa: E402
from matplotlib.colors import LinearSegmentedColormap, TwoSlopeNorm  # noqa: E402

from toolkit import Project, style, save, bar_h, PALETTE, INK_2  # noqa: E402
from toolkit.charts import DIVERGING  # noqa: E402

SOURCE = "Open-Meteo historical weather API (ERA5 reanalysis, Copernicus), grid cell over Paris, CC BY 4.0"


def main(p: Project) -> None:
    style()

    # 1. Warming stripes: one stripe per year, diverging around the 1951-1980 average (gray = average).
    y = p.result("yearly")
    cmap = LinearSegmentedColormap.from_list("div", list(DIVERGING))
    limit = max(abs(y["anomaly"].min()), abs(y["anomaly"].max()))
    fig, ax = plt.subplots(figsize=(11, 3.4))
    ax.bar(y["year"], 1, width=1.0, color=cmap(TwoSlopeNorm(0, -limit, limit)(y["anomaly"])), linewidth=0)
    ax.set_xlim(y["year"].min() - 0.5, y["year"].max() + 0.5)
    ax.set_ylim(0, 1)
    ax.set_yticks([])
    ax.set_xticks([1950, 1970, 1990, 2010, 2025])
    ax.grid(False)
    for s in ax.spines.values():
        s.set_visible(False)
    ax.set_title("Paris, 1950 → 2025: every year since 2011 has been warmer than the 1951-1980 average")
    save(fig, p.images / "warming_stripes.png", SOURCE,
         "One stripe per year, colored by mean temperature vs the 1951-1980 average (blue = colder, red = warmer)")

    # 2. Hot days per year, by decade (single series).
    d = p.result("decades")
    fig, ax = plt.subplots(figsize=(9, 4))
    bars = ax.bar([f"{x}s" for x in d["decade"]], d["hot_days_per_year"], color=PALETTE[7], width=0.66)
    for b, v in zip(bars, d["hot_days_per_year"]):
        ax.text(b.get_x() + b.get_width() / 2, v + 0.3, f"{v:.1f}", ha="center", fontsize=9, color=INK_2)
    ax.grid(axis="x", visible=False)
    ax.set_title("Days at 30 °C or more: from about 2 a year to almost 14")
    save(fig, p.images / "hot_days.png", SOURCE, "Average number of days per year with a maximum of 30 °C or more, by decade (2020s = 2020-2025)")

    # 3. Warming by month.
    m = p.result("monthly_warming")
    months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    fig, ax = plt.subplots(figsize=(8.5, 5.2))
    order = m.sort_values("warming_c", ascending=False)
    bar_h(ax, [months[i - 1] for i in order["month"]], order["warming_c"], color=PALETTE[7], fmt=lambda v: f"+{v:.1f} °C")
    ax.set_title("Summers warmed most: August is 1.8 °C hotter than in 1951-1980")
    save(fig, p.images / "monthly_warming.png", SOURCE, "Average temperature 1996-2025 minus 1951-1980, by month")


if __name__ == "__main__":
    main(Project.here(__file__))
