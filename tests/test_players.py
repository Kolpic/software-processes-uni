from courtside import store, teams, players

import pytest


def _db_with_team():
    db = store.new_db()
    teams.create_team(db, "Celtics")
    return db


def test_add_player():
    db = _db_with_team()
    pl = players.add_player(db, 1, "Tatum", 0)
    assert pl["id"] == 1
    assert pl["team_id"] == 1
    assert len(db["players"]) == 1


def test_add_player_unknown_team_rejected():
    db = _db_with_team()
    with pytest.raises(ValueError):
        players.add_player(db, 99, "Ghost")
