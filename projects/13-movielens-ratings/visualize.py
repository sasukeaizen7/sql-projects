"""Charts for the MovieLens project."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
import matplotlib.pyplot as plt  # noqa: E402

from toolkit import Project, style, save, bar_h, PALETTE, INK_2, SURFACE  # noqa: E402

SOURCE = "GroupLens, MovieLens latest-small (Harper & Konstan, 2015)"


def main(p: Project) -> None:
    style()

    w = p.result("weighted_top").head(10)
    fig, ax = plt.subplots(figsize=(9, 5))
    labels = [f"{t}  ({n} ratings)" for t, n in zip(w["title"].str.replace(r"^(.*), The (\(\d{4}\))$", r"The \1 \2", regex=True), w["ratings"])]
    bar_h(ax, labels, w["weighted_rating"], fmt=lambda v: f"{v:.2f}")
    ax.set_title("With a vote-weighted score, the classics rise to the top")
    save(fig, p.images / "weighted_top.png", SOURCE,
         "Top 10 by IMDb-style weighted rating (m = 50 votes, shrinks small samples toward the 3.50 mean)")

    g = p.result("genres")
    fig, ax = plt.subplots(figsize=(10, 5.4))
    ax.scatter(g["ratings"], g["avg_rating"], s=60, color=PALETTE[0], edgecolors=SURFACE, linewidths=1.5, zorder=3)
    nudge = {"Mystery": (6, -12)}  # avoid overlapping Animation, which sits right next to it
    for _, r in g.iterrows():
        ax.annotate(r["genre"], (r["ratings"], r["avg_rating"]), xytext=nudge.get(r["genre"], (6, 4)),
                    textcoords="offset points", fontsize=8.5, color=INK_2)
    ax.set_xscale("log")
    ax.xaxis.set_major_formatter(lambda v, _: f"{v:,.0f}")
    ax.set_xlabel("Number of ratings (log scale)")
    ax.set_ylabel("Average rating")
    ax.set_title("Niche genres score higher: Film-Noir, War and Documentary beat Comedy and Horror")
    save(fig, p.images / "genres.png", SOURCE, "Popularity (ratings) vs appreciation (average rating) by genre")

    d = p.result("by_decade")
    fig, ax = plt.subplots(figsize=(9, 4))
    x = [f"{v}s" for v in d["decade"]]
    ax.plot(x, d["avg_rating"], color=PALETTE[0], marker="o", markersize=8, markeredgecolor=SURFACE, markeredgewidth=2)
    for xi, v in zip(x, d["avg_rating"]):
        ax.annotate(f"{v:.2f}", (xi, v), xytext=(0, 10), textcoords="offset points", ha="center", fontsize=9, color=INK_2)
    ax.set_ylim(3.3, 4.0)
    ax.grid(axis="x", visible=False)
    ax.set_title("Older films get better ratings, likely survivorship: only the classics are still watched")
    save(fig, p.images / "by_decade.png", SOURCE, "Average rating by release decade")

if __name__ == "__main__":
    main(Project.here(__file__))
