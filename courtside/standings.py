"""League standings and scoring leaderboard (computed from games)."""
from __future__ import annotations


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
