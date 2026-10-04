from courtside import store, teams, players, games, standings


def test_leaderboard():
    db = store.new_db()
    teams.create_team(db, "Lakers")   # id 1
    teams.create_team(db, "Bulls")    # id 2
    players.add_player(db, 1, "Scorer")       # id 1
    players.add_player(db, 2, "Role Player")  # id 2
    games.schedule_game(db, 1, 2, "2026-10-10")   # game 1
    games.record_player_stats(db, 1, 1, 30)
    games.record_player_stats(db, 1, 2, 8)
    board = standings.leaderboard(db)
    assert board[0]["name"] == "Scorer"
    assert board[0]["points"] == 30


def test_standings_counts_only_finished_games():
    db = store.new_db()
    teams.create_team(db, "Lakers")   # id 1
    teams.create_team(db, "Bulls")    # id 2
    teams.create_team(db, "Heat")     # id 3
    games.schedule_game(db, 1, 2, "2026-10-10")   # game 1, no score yet
    games.schedule_game(db, 1, 3, "2026-10-12")   # game 2
    games.record_score(db, 2, 100, 90)            # Lakers beat Heat
    table = standings.compute_standings(db)
    top = table[0]
    assert top["name"] == "Lakers"
    assert top["played"] == 1 and top["wins"] == 1


def test_editing_a_score_updates_standings():
    """Regression test for bug BB-14."""
    db = store.new_db()
    teams.create_team(db, "Lakers")   # id 1
    teams.create_team(db, "Bulls")    # id 2
    games.schedule_game(db, 1, 2, "2026-10-10")   # game 1
    games.record_score(db, 1, 80, 70)             # Lakers win
    assert standings.compute_standings(db)[0]["name"] == "Lakers"
    games.record_score(db, 1, 70, 80)             # correction: Bulls win
    assert standings.compute_standings(db)[0]["name"] == "Bulls"
