"""Charts for the energy transition project."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
import matplotlib.pyplot as plt  # noqa: E402
import numpy as np  # noqa: E402

from toolkit import Project, style, save, PALETTE, INK_2, GRID  # noqa: E402

SOURCE = "Our World in Data, Energy dataset (Ember, Energy Institute), CC BY 4.0"


def end_label(ax, x, y, text, dy=0):
    ax.annotate(text, (x, y), xytext=(8, dy), textcoords="offset points", va="center", fontsize=9, color=INK_2)


def main(p: Project) -> None:
    style()

    # 1. World electricity mix by family, same unit (% of generation), lines labeled at the end.
    w = p.result("world_mix")
    series = [("Fossil", "fossil_pct"), ("Wind + solar", "wind_solar_pct"), ("Hydro & other renewables", "hydro_other_pct"), ("Nuclear", "nuclear_pct")]
    fig, ax = plt.subplots(figsize=(10, 4.8))
    for (name, col), color in zip(series, PALETTE):
        ax.plot(w["year"], w[col], color=color, label=name)
        end_label(ax, w["year"].iloc[-1], w[col].iloc[-1], f"{name} {w[col].iloc[-1]:.1f}%",
                  dy={"Wind + solar": 6, "Hydro & other renewables": -6}.get(name, 0))
    ax.set_xlim(2000, 2025)
    ax.set_ylim(0, 75)
    ax.yaxis.set_major_formatter(lambda v, _: f"{v:.0f}%")
    ax.legend(loc="upper right", ncols=2)
    ax.set_title("Wind and solar passed nuclear in 2021 and hydro in 2025")
    save(fig, p.images / "world_mix.png", SOURCE, "Share of world electricity generation by source family, 2000-2025")

    # 2. Dumbbell: wind + solar share 2015 -> 2024 for the fastest movers.
    f = p.result("fastest_wind_solar").iloc[::-1]
    y = np.arange(len(f))
    fig, ax = plt.subplots(figsize=(9, 5.6))
    ax.hlines(y, f["share_2015"], f["share_2024"], color=GRID, linewidth=3, zorder=1)
    ax.scatter(f["share_2015"], y, color=PALETTE[0], s=60, zorder=2, label="2015")
    ax.scatter(f["share_2024"], y, color=PALETTE[1], s=60, zorder=2, label="2024")
    for yy, v, g in zip(y, f["share_2024"], f["gain_pp"]):
        ax.text(v + 1.2, yy, f"+{g:.0f} pts", va="center", fontsize=9, color=INK_2)
    ax.set_yticks(y, f["country"])
    ax.tick_params(axis="y", length=0)
    ax.grid(axis="y", visible=False)
    ax.set_xlim(0, f["share_2024"].max() + 9)
    ax.xaxis.set_major_formatter(lambda v, _: f"{v:.0f}%")
    ax.legend(loc="lower right", bbox_to_anchor=(1, 0.1))
    ax.set_title("The Netherlands went from 8% to 45% wind and solar in nine years")
    save(fig, p.images / "fastest_wind_solar.png", SOURCE,
         "Wind + solar share of electricity, 2015 vs 2024, biggest gains (countries of 10M+ people)")

    # 3. Carbon intensity: France vs Germany vs UK.
    e = p.result("europe_intensity")
    fig, ax = plt.subplots(figsize=(10, 4.4))
    for (country, g), color in zip(e.groupby("country", sort=False), PALETTE):
        ax.plot(g["year"], g["g_co2_per_kwh"], color=color, label=country)
        end_label(ax, g["year"].iloc[-1], g["g_co2_per_kwh"].iloc[-1], f"{country} {g['g_co2_per_kwh'].iloc[-1]:.0f} g")
    ax.set_xlim(2000, 2024)
    ax.set_ylim(0, 650)
    ax.legend(loc="upper right")
    ax.set_title("French electricity emits 8× less CO₂ per kWh than Germany's")
    save(fig, p.images / "carbon_intensity.png", SOURCE, "Carbon intensity of electricity, grams of CO₂ per kWh")


if __name__ == "__main__":
    main(Project.here(__file__))
