"""Manage the players on a team's roster."""
from __future__ import annotations

from . import store, teams


def add_player(db: dict, team_id: int, name: str, number: int | None = None) -> dict:
    """Add a player to a team and return the player."""
    teams.get_team(db, team_id)  # validates that the team exists
    player = {
        "id": store.next_id(db["players"]),
        "team_id": team_id,
        "name": name,
        "number": number,
    }
    db["players"].append(player)
    return player


def get_player(db: dict, player_id: int) -> dict:
    """Return a player by id or raise ValueError."""
    for player in db["players"]:
        if player["id"] == player_id:
            return player
    raise ValueError(f"No player with id {player_id}")
