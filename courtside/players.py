"""Manage the players on a team's roster."""
from __future__ import annotations

from . import store, teams


def add_player(db: dict, team_id: int, name: str, number: int | None = None) -> dict:
    """Add a player to a team and return the player."""
    teams.get_team(db, team_id)  # validates that the team exists
    name = (name or "").strip()
    if not name:
        raise ValueError("Player name cannot be empty")
    player = {
        "id": store.next_id(db["players"]),
        "team_id": team_id,
        "name": name,
        "number": number,
    }
    db["players"].append(player)
    return player


def get_roster(db: dict, team_id: int) -> list:
    """Return all players of a team."""
    teams.get_team(db, team_id)
    return [p for p in db["players"] if p["team_id"] == team_id]


def get_player(db: dict, player_id: int) -> dict:
    """Return a player by id or raise ValueError."""
    for player in db["players"]:
        if player["id"] == player_id:
            return player
    raise ValueError(f"No player with id {player_id}")


def update_player(db: dict, player_id: int, name: str | None = None,
                  number: int | None = None) -> dict:
    """Update a player's name and/or shirt number."""
    player = get_player(db, player_id)
    if name is not None:
        name = name.strip()
        if not name:
            raise ValueError("Player name cannot be empty")
        player["name"] = name
    if number is not None:
        player["number"] = number
    return player


def remove_player(db: dict, player_id: int) -> None:
    """Remove a player from the roster."""
    player = get_player(db, player_id)
    db["players"].remove(player)
