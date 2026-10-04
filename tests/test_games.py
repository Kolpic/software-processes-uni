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


def test_record_score():
    db = _db_two_teams()
    games.schedule_game(db, 1, 2, "2026-10-10")
    game = games.record_score(db, 1, 88, 77)
    assert games.is_finished(game)
    assert game["home_score"] == 88


def test_record_player_stats_replaces():
    from courtside import players
    db = _db_two_teams()
    players.add_player(db, 1, "Player A")   # id 1
    games.schedule_game(db, 1, 2, "2026-10-10")
    games.record_player_stats(db, 1, 1, 10)
    games.record_player_stats(db, 1, 1, 25)  # correction
    game = games.get_game(db, 1)
    assert len(game["stats"]) == 1
    assert game["stats"][0]["points"] == 25
