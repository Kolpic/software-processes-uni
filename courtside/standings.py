"""League standings and scoring leaderboard (computed from games)."""
from __future__ import annotations

from . import games


def compute_standings(db: dict) -> list:
    """Return standings sorted by wins, then point difference.

    The table is always recomputed from the finished games, so correcting a
    score is reflected immediately (this is the fix for bug BB-14).
    """
    table = {
        t["id"]: {
            "team_id": t["id"],
            "name": t["name"],
            "played": 0, "wins": 0, "losses": 0,
            "points_for": 0, "points_against": 0,
        }
        for t in db["teams"]
    }
    for game in db["games"]:
        if not games.is_finished(game):
            continue
        home, away = table[game["home_id"]], table[game["away_id"]]
        home["played"] += 1
        away["played"] += 1
        home["points_for"] += game["home_score"]
        home["points_against"] += game["away_score"]
        away["points_for"] += game["away_score"]
        away["points_against"] += game["home_score"]
        if game["home_score"] > game["away_score"]:
            home["wins"] += 1
            away["losses"] += 1
        else:
            away["wins"] += 1
            home["losses"] += 1
    rows = list(table.values())
    rows.sort(key=lambda r: (r["wins"], r["points_for"] - r["points_against"]),
              reverse=True)
    return rows


def leaderboard(db: dict, top: int = 10) -> list:
    """Return the top scorers across all games."""
    totals: dict[int, int] = {}
    for game in db["games"]:
        for s in game["stats"]:
            totals[s["player_id"]] = totals.get(s["player_id"], 0) + s["points"]
    names = {p["id"]: p["name"] for p in db["players"]}
    rows = [{"player_id": pid, "name": names.get(pid, "?"), "points": pts}
            for pid, pts in totals.items()]
    rows.sort(key=lambda r: r["points"], reverse=True)
    return rows[:top]
