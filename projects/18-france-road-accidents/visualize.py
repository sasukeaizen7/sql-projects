"""Charts for the French road accidents project."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
import matplotlib.pyplot as plt  # noqa: E402
import numpy as np  # noqa: E402

from toolkit import Project, style, save, bar_h, PALETTE, INK_2  # noqa: E402

SOURCE = "ONISR, Bases de données annuelles des accidents corporels de la circulation routière 2024 (BAAC), data.gouv.fr"


def main(p: Project) -> None:
    style()

    # 1. Lethality by mode of travel.
    m = p.result("by_mode")
    m = m[m["mode"] != "Other"]
    fig, ax = plt.subplots(figsize=(9, 4.8))
    bar_h(ax, [f"{x} ({n:,} involved)" for x, n in zip(m["mode"], m["people_involved"])], m["killed_per_100_involved"],
          fmt=lambda v: f"{v:.1f}")
    ax.set_title("Pedestrians and motorcyclists are about twice as likely to die as car occupants")
    save(fig, p.images / "lethality_by_mode.png", SOURCE, "People killed per 100 people involved in an injury accident, 2024")

    # 2. Built-up vs rural: share of accidents vs share of deaths (same unit, grouped bars).
    u = p.result("urban_vs_rural")
    x = np.arange(len(u))
    fig, ax = plt.subplots(figsize=(8.5, 4.2))
    b1 = ax.bar(x - 0.19, u["accidents_pct"], width=0.36, color=PALETTE[0], label="% of accidents")
    b2 = ax.bar(x + 0.19, u["deaths_pct"], width=0.36, color=PALETTE[1], label="% of deaths")
    for bars in (b1, b2):
        for b in bars:
            ax.text(b.get_x() + b.get_width() / 2, b.get_height() + 1, f"{b.get_height():.0f}%", ha="center", fontsize=9, color=INK_2)
    ax.set_xticks(x, u["area"])
    ax.set_ylim(0, 80)
    ax.yaxis.set_major_formatter(lambda v, _: f"{v:.0f}%")
    ax.grid(axis="x", visible=False)
    ax.legend(loc="upper left")
    ax.set_title("Outside towns: 38% of accidents, but 68% of deaths")
    save(fig, p.images / "urban_vs_rural.png", SOURCE, "Injury accidents and road deaths by location, France 2024")

    # 3. Age: deaths per 100 people involved (ordered bands, single hue).
    a = p.result("by_age")
    fig, ax = plt.subplots(figsize=(9, 4))
    bars = ax.bar(a["age_band"].str[3:], a["killed_per_100_involved"], color=PALETTE[0], width=0.66)
    for b, v in zip(bars, a["killed_per_100_involved"]):
        ax.text(b.get_x() + b.get_width() / 2, v + 0.1, f"{v:.1f}", ha="center", fontsize=9, color=INK_2)
    ax.grid(axis="x", visible=False)
    ax.set_xlabel("Age")
    ax.set_title("Over-75s involved in an accident are 3.4× more likely to die than 18-24s")
    save(fig, p.images / "lethality_by_age.png", SOURCE, "People killed per 100 people involved in an injury accident, by age, 2024")


if __name__ == "__main__":
    main(Project.here(__file__))
