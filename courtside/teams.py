"""Create and read teams."""
from __future__ import annotations

from . import store


def create_team(db: dict, name: str) -> dict:
    """Register a new team and return it.

    Raises ValueError if the name is empty or already used.
    """
    name = (name or "").strip()
    if not name:
        raise ValueError("Team name cannot be empty")
    if any(t["name"].lower() == name.lower() for t in db["teams"]):
        raise ValueError(f"Team '{name}' already exists")
    team = {"id": store.next_id(db["teams"]), "name": name}
    db["teams"].append(team)
    return team


def list_teams(db: dict) -> list:
    """Return all teams."""
    return db["teams"]


def get_team(db: dict, team_id: int) -> dict:
    """Return a team by id or raise ValueError."""
    for team in db["teams"]:
        if team["id"] == team_id:
            return team
    raise ValueError(f"No team with id {team_id}")
