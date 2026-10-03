"""Charts for the Paris trees project."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
import matplotlib.pyplot as plt  # noqa: E402
from matplotlib.patches import Patch  # noqa: E402

from toolkit import Project, style, save, bar_h, PALETTE  # noqa: E402

SOURCE = "Ville de Paris, Les arbres (opendata.paris.fr), ODbL"


def main(p: Project) -> None:
    style()

    t = p.result("top_species")
    fig, ax = plt.subplots(figsize=(8.5, 4.8))
    bar_h(ax, t["species_fr"] + " (" + t["genus"] + ")", t["trees"], fmt=lambda v: f"{v:,.0f}")
    ax.set_title("1 tree in 5 managed by Paris is a plane tree")
    save(fig, p.images / "top_species.png", SOURCE, "Number of trees by species, top 10 of 220,174")

    m = p.result("street_monoculture")
    fig, ax = plt.subplots(figsize=(8.5, 6.6))
    labels = ["1er" if n == 1 else f"{n}e" for n in m["arrondissement"]]
    bars = bar_h(ax, labels, m["top_genus_pct"], fmt=lambda v: f"{v:.0f}%")
    colors = {"Platanus": PALETTE[0], "Aesculus": PALETTE[1]}
    for b, g in zip(bars, list(m["top_genus"])[::-1]):
        b.set_color(colors.get(g, PALETTE[2]))
    ax.legend(handles=[Patch(color=PALETTE[0], label="Plane tree (Platanus)"),
                       Patch(color=PALETTE[1], label="Horse chestnut (Aesculus)")], loc="lower right")
    ax.set_title("In the 5e, 6e, 7e and 8e, over half of all street trees are a single genus")
    save(fig, p.images / "street_monoculture.png", SOURCE,
         "Share of street trees belonging to the most common genus, by arrondissement")

    h = p.result("height_by_genus").sort_values("median_height_m", ascending=False)
    fig, ax = plt.subplots(figsize=(8.5, 4.8))
    bar_h(ax, h["genus"], h["median_height_m"], fmt=lambda v: f"{v:.0f} m")
    ax.set_title("Plane trees are also the tallest common trees")
    save(fig, p.images / "height_by_genus.png", SOURCE, "Median height of the 10 most common genera (measured trees only)")


if __name__ == "__main__":
    main(Project.here(__file__))
