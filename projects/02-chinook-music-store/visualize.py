"""Charts for the Chinook music store project."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
import matplotlib.pyplot as plt  # noqa: E402

from toolkit import Project, style, save, bar_h  # noqa: E402

SOURCE = "Chinook sample database (lerocha/chinook-database v1.4.5)"


def main(p: Project) -> None:
    style()

    g = p.result("revenue_by_genre")
    fig, ax = plt.subplots(figsize=(8.5, 4.8))
    bar_h(ax, g["genre"], g["share_pct"], fmt=lambda v: f"{v:.1f}%")
    ax.set_title("Rock alone is a third of all track sales")
    save(fig, p.images / "revenue_by_genre.png", SOURCE, "Share of track revenue by genre, top 10 (%)")

    c = p.result("revenue_by_country")
    fig, ax = plt.subplots(figsize=(8.5, 4.8))
    bar_h(ax, c["country"], c["revenue"], fmt=lambda v: f"${v:,.0f}")
    ax.set_title("The USA and Canada bring in a third of revenue")
    save(fig, p.images / "revenue_by_country.png", SOURCE, "Total invoiced revenue by customer country, top 10 (USD)")

    m = p.result("catalog_coverage")
    fig, ax = plt.subplots(figsize=(8.5, 3.6))
    labels = [f"{t} ({n:,} tracks)" for t, n in zip(m["media_type"], m["tracks"])]
    bar_h(ax, labels, m["never_sold_pct"], fmt=lambda v: f"{v:.0f}%")
    ax.set_title("Almost half of the catalog has never been sold")
    save(fig, p.images / "catalog_coverage.png", SOURCE, "Share of tracks with zero sales, by media type")


if __name__ == "__main__":
    main(Project.here(__file__))
