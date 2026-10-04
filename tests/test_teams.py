from courtside import store, teams

import pytest


def test_create_team():
    db = store.new_db()
    team = teams.create_team(db, "Lakers")
    assert team["id"] == 1
    assert team["name"] == "Lakers"
    assert len(db["teams"]) == 1


def test_create_team_empty_name_rejected():
    db = store.new_db()
    with pytest.raises(ValueError):
        teams.create_team(db, "   ")


def test_create_team_duplicate_rejected():
    db = store.new_db()
    teams.create_team(db, "Bulls")
    with pytest.raises(ValueError):
        teams.create_team(db, "bulls")
