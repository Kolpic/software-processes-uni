"""JSON-backed persistence for CourtSide.

The whole application state (teams, players, games) lives in a single JSON
file so the project stays dependency-free and the data is easy to inspect.
Business-logic modules work on a plain ``dict`` (called ``db``); the CLI is
the only layer that loads from / saves to disk.
"""
from __future__ import annotations

import json
import os

DEFAULT_PATH = os.environ.get("COURTSIDE_DB", "courtside_data.json")


def new_db() -> dict:
    """Return an empty database structure."""
    return {"teams": [], "players": [], "games": []}


def load(path: str = DEFAULT_PATH) -> dict:
    """Load the database from ``path`` (or return an empty one)."""
    if not os.path.exists(path):
        return new_db()
    with open(path, "r", encoding="utf-8") as fh:
        return json.load(fh)


def save(db: dict, path: str = DEFAULT_PATH) -> None:
    """Persist the database to ``path``."""
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(db, fh, ensure_ascii=False, indent=2)


def next_id(items: list) -> int:
    """Return the next integer id for a collection."""
    return max((item["id"] for item in items), default=0) + 1
