"""Shared helpers for the SQL portfolio projects.

Each project follows the same pipeline:
    download raw data  ->  load into DuckDB with SQL  ->  answer questions with SQL  ->  chart the answers in Python
"""

from .pipeline import Project
from .charts import style, save, bar_h, line, PALETTE, SURFACE, INK, INK_2, MUTED, GRID

__all__ = ["Project", "style", "save", "bar_h", "line", "PALETTE", "SURFACE", "INK", "INK_2", "MUTED", "GRID"]
