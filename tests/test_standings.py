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
