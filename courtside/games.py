"""Schedule games and record results and player box scores."""
from __future__ import annotations

from . import store, teams


def schedule_game(db: dict, home_id: int, away_id: int, date: str) -> dict:
    """Create a scheduled game between two different teams."""
    if home_id == away_id:
        raise ValueError("A team cannot play against itself")
    teams.get_team(db, home_id)
    teams.get_team(db, away_id)
    game = {
        "id": store.next_id(db["games"]),
        "home_id": home_id,
        "away_id": away_id,
        "date": date,
        "home_score": None,
        "away_score": None,
        "stats": [],  # list of {player_id, points}
    }
    db["games"].append(game)
    return game


def get_game(db: dict, game_id: int) -> dict:
    """Return a game by id or raise ValueError."""
    for game in db["games"]:
        if game["id"] == game_id:
            return game
    raise ValueError(f"No game with id {game_id}")


def record_score(db: dict, game_id: int, home_score: int, away_score: int) -> dict:
    """Record (or correct) the final score of a game."""
    game = get_game(db, game_id)
    game["home_score"] = home_score
    game["away_score"] = away_score
    return game


def is_finished(game: dict) -> bool:
    """A game counts for the standings only once it has a score."""
    return game["home_score"] is not None and game["away_score"] is not None
