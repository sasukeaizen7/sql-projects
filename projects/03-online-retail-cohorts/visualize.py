"""Charts for the Online Retail II project: cohort retention, seasonality, RFM segments."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
import matplotlib.pyplot as plt  # noqa: E402
import numpy as np  # noqa: E402
import pandas as pd  # noqa: E402
from matplotlib.colors import LinearSegmentedColormap  # noqa: E402

from toolkit import Project, style, save, PALETTE, INK, INK_2  # noqa: E402
from toolkit.charts import BLUES, THOUSANDS  # noqa: E402

SOURCE = "UCI Machine Learning Repository, Online Retail II (Chen, 2019), CC BY 4.0"


def main(p: Project) -> None:
    style()

    # 1. Cohort retention heatmap. Numbers are printed because a cohort grid is read like a table.
    c = p.result("cohort_retention")
    c = c[c["month_number"] > 0]
    grid = c.pivot(index="cohort", columns="month_number", values="retention_pct")
    sizes = p.result("cohort_retention").query("month_number == 0").set_index("cohort")["cohort_size"]
    fig, ax = plt.subplots(figsize=(11, 5.6))
    im = ax.imshow(grid.values, aspect="auto", cmap=LinearSegmentedColormap.from_list("b", BLUES), vmin=0, vmax=50)
    labels = [f"{pd.Timestamp(i):%b %Y}  ({sizes[i]:,})" for i in grid.index]
    ax.set_yticks(range(len(labels)), labels)
    ax.set_xticks(range(grid.shape[1]), [f"+{m}" for m in grid.columns])
    ax.set_xlabel("Months after first purchase")
    ax.grid(False)
    for s in ax.spines.values():
        s.set_visible(False)
    for (i, j), v in np.ndenumerate(grid.values):
        if not np.isnan(v):
            ax.text(j, i, f"{v:.0f}", ha="center", va="center", fontsize=8.5, color="white" if v >= 30 else INK)
    ax.set_title("Customers won in 2010 come back far less often than the existing base")
    save(fig, p.images / "cohort_retention.png", SOURCE,
         "% of each cohort still buying N months later. Dec 2009 = first month of data, i.e. the existing customer base")

    # 2. Monthly revenue: strong Q4 seasonality.
    m = p.result("monthly_revenue")
    m = m[m["month"] < "2011-12-01"]  # December 2011 stops on the 9th
    fig, ax = plt.subplots(figsize=(10.5, 4))
    x = pd.to_datetime(m["month"]).dt.strftime("%b %y")
    bars = ax.bar(x, m["revenue"], color=PALETTE[0], width=0.72)
    for b, month in zip(bars, m["month"]):
        if month[5:7] != "11":
            b.set_alpha(0.35)
    ax.yaxis.set_major_formatter(lambda v, _: f"£{v / 1e6:.1f}M")
    ax.set_xticks(range(0, len(x), 2), x[::2])
    ax.grid(axis="x", visible=False)
    ax.set_title("Every November is the peak month (Christmas orders)")
    save(fig, p.images / "monthly_revenue.png", SOURCE, "Monthly revenue in GBP, Dec 2009 to Nov 2011 (November highlighted)")

    # 3. RFM: share of customers vs share of revenue, per segment (same unit, one axis).
    r = p.result("rfm_segments")
    seg = r["segment"].str[3:]
    y = np.arange(len(r))[::-1]
    fig, ax = plt.subplots(figsize=(9, 4.6))
    ax.barh(y + 0.19, r["customers_pct"], height=0.36, color=PALETTE[0], label="% of customers")
    ax.barh(y - 0.19, r["revenue_pct"], height=0.36, color=PALETTE[1], label="% of revenue")
    for yy, a, b in zip(y, r["customers_pct"], r["revenue_pct"]):
        ax.text(a + 0.8, yy + 0.19, f"{a:.0f}%", va="center", fontsize=9, color=INK_2)
        ax.text(b + 0.8, yy - 0.19, f"{b:.0f}%", va="center", fontsize=9, color=INK_2)
    ax.set_yticks(y, seg)
    ax.tick_params(axis="y", length=0)
    ax.grid(axis="y", visible=False)
    ax.xaxis.set_major_formatter(lambda v, _: f"{v:.0f}%")
    ax.set_xlim(0, max(r["revenue_pct"].max(), r["customers_pct"].max()) * 1.12)
    ax.legend(loc="lower right")
    ax.set_title("Champions are 22% of customers but 69% of revenue")
    save(fig, p.images / "rfm_segments.png", SOURCE, "RFM segments built with NTILE(5) scores on recency, frequency and monetary value")


if __name__ == "__main__":
    main(Project.here(__file__))
