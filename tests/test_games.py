from courtside import store, teams, games

import pytest


def _db_two_teams():
    db = store.new_db()
    teams.create_team(db, "Lakers")   # id 1
    teams.create_team(db, "Bulls")    # id 2
    return db


def test_schedule_game():
    db = _db_two_teams()
    game = games.schedule_game(db, 1, 2, "2026-10-10")
    assert game["home_id"] == 1 and game["away_id"] == 2
    assert not games.is_finished(game)


def test_cannot_play_itself():
    db = _db_two_teams()
    with pytest.raises(ValueError):
        games.schedule_game(db, 1, 1, "2026-10-10")
