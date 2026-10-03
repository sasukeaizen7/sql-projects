"""Charts for the Paris real estate (DVF) project."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
import matplotlib.pyplot as plt  # noqa: E402
import pandas as pd  # noqa: E402

from toolkit import Project, style, save, bar_h, PALETTE, INK_2  # noqa: E402
from toolkit.charts import DIVERGING  # noqa: E402

SOURCE = "DGFiP, Demandes de valeurs foncières (DVF) via data.gouv.fr, Licence Ouverte 2.0"


def arr(n: int) -> str:
    return "1er" if n == 1 else f"{n}e"


def main(p: Project) -> None:
    style()
    a = p.result("by_arrondissement")

    # 1. Price level by arrondissement.
    s = a.sort_values("median_m2_2024", ascending=False)
    fig, ax = plt.subplots(figsize=(8.5, 6.6))
    bar_h(ax, [arr(n) for n in s["arrondissement"]], s["median_m2_2024"], fmt=lambda v: f"{v / 1000:.1f}k €")
    ax.set_title("The 6e and 7e cost almost twice the 19e per m²")
    save(fig, p.images / "price_by_arrondissement.png", SOURCE,
         "Median price per m² of apartment sales in 2024, by arrondissement")

    # 2. Change 2023 -> 2024: every arrondissement fell (negative pole of the diverging pair).
    c = a.sort_values("change_pct")
    fig, ax = plt.subplots(figsize=(8.5, 6.6))
    labels = [arr(n) for n in c["arrondissement"]]
    ax.barh(labels[::-1], c["change_pct"][::-1], color=DIVERGING[2], height=0.68)
    for y, v in enumerate(c["change_pct"][::-1]):
        ax.text(v - 0.15, y, f"{v:.1f}%", va="center", ha="right", fontsize=9, color=INK_2)
    ax.set_xlim(c["change_pct"].min() * 1.18, 0)
    ax.axvline(0, color=INK_2, linewidth=0.8)
    ax.xaxis.set_major_formatter(lambda v, _: f"{v:.0f}%")
    ax.grid(axis="y", visible=False)
    ax.tick_params(axis="y", length=0)
    ax.set_title("Prices fell in all 20 arrondissements in 2024")
    save(fig, p.images / "change_by_arrondissement.png", SOURCE,
         "Change in median price per m², 2024 vs 2023 (apartments)")

    # 3. Monthly trend.
    m = p.result("monthly")
    x = pd.to_datetime(m["month"])
    fig, ax = plt.subplots(figsize=(10, 4))
    ax.plot(x, m["median_eur_m2"], color=PALETTE[0], alpha=0.35, linewidth=1.5, label="Monthly median")
    ax.plot(x, m["median_m2_3m_avg"], color=PALETTE[0], label="3-month average")
    ax.annotate(f"{m['median_m2_3m_avg'].iloc[0]:,.0f} €", (x.iloc[0], m["median_m2_3m_avg"].iloc[0]),
                xytext=(0, 8), textcoords="offset points", fontsize=9, color=INK_2)
    ax.annotate(f"{m['median_m2_3m_avg'].iloc[-1]:,.0f} €", (x.iloc[-1], m["median_m2_3m_avg"].iloc[-1]),
                xytext=(-10, 10), textcoords="offset points", fontsize=9, color=INK_2, ha="right")
    ax.yaxis.set_major_formatter(lambda v, _: f"{v:,.0f} €")
    ax.legend(loc="upper right")
    ax.set_title("Prices fell until spring 2024, then held around 9,600 €/m²")
    save(fig, p.images / "monthly_trend.png", SOURCE, "Median price per m² of Paris apartment sales, by month")


if __name__ == "__main__":
    main(Project.here(__file__))
