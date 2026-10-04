"""Command-line interface for CourtSide."""
from __future__ import annotations

import argparse

from . import store, teams, players, games, standings


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="courtside", description="Amateur basketball league manager")
    sub = parser.add_subparsers(dest="command", required=True)

    p = sub.add_parser("add-team", help="Create a team")
    p.add_argument("name")

    sub.add_parser("list-teams", help="List all teams")

    p = sub.add_parser("add-player", help="Add a player to a team")
    p.add_argument("team_id", type=int)
    p.add_argument("name")
    p.add_argument("--number", type=int)

    p = sub.add_parser("roster", help="Show a team's roster")
    p.add_argument("team_id", type=int)

    p = sub.add_parser("edit-player", help="Edit a player")
    p.add_argument("player_id", type=int)
    p.add_argument("--name")
    p.add_argument("--number", type=int)

    p = sub.add_parser("remove-player", help="Remove a player")
    p.add_argument("player_id", type=int)

    p = sub.add_parser("schedule", help="Schedule a game")
    p.add_argument("home_id", type=int)
    p.add_argument("away_id", type=int)
    p.add_argument("date")

    p = sub.add_parser("score", help="Record a game's final score")
    p.add_argument("game_id", type=int)
    p.add_argument("home_score", type=int)
    p.add_argument("away_score", type=int)

    p = sub.add_parser("player-stats", help="Record a player's points in a game")
    p.add_argument("game_id", type=int)
    p.add_argument("player_id", type=int)
    p.add_argument("points", type=int)

    sub.add_parser("standings", help="Show the league standings")
    sub.add_parser("leaderboard", help="Show the top scorers")
    return parser


def main(argv=None) -> int:
    args = build_parser().parse_args(argv)
    db = store.load()

    if args.command == "add-team":
        team = teams.create_team(db, args.name)
        print(f"Created team #{team['id']}: {team['name']}")
    elif args.command == "list-teams":
        for t in teams.list_teams(db):
            print(f"#{t['id']} {t['name']}")
    elif args.command == "add-player":
        pl = players.add_player(db, args.team_id, args.name, args.number)
        print(f"Added player #{pl['id']}: {pl['name']}")
    elif args.command == "roster":
        for pl in players.get_roster(db, args.team_id):
            num = f" (#{pl['number']})" if pl["number"] is not None else ""
            print(f"#{pl['id']} {pl['name']}{num}")
    elif args.command == "edit-player":
        pl = players.update_player(db, args.player_id, args.name, args.number)
        print(f"Updated player #{pl['id']}: {pl['name']}")
    elif args.command == "remove-player":
        players.remove_player(db, args.player_id)
        print(f"Removed player #{args.player_id}")
    elif args.command == "schedule":
        g = games.schedule_game(db, args.home_id, args.away_id, args.date)
        print(f"Scheduled game #{g['id']} on {g['date']}")
    elif args.command == "score":
        g = games.record_score(db, args.game_id, args.home_score, args.away_score)
        print(f"Game #{g['id']}: {g['home_score']}-{g['away_score']}")
    elif args.command == "player-stats":
        s = games.record_player_stats(db, args.game_id, args.player_id, args.points)
        print(f"Player #{s['player_id']} scored {s['points']}")
    elif args.command == "standings":
        for r in standings.compute_standings(db):
            diff = r["points_for"] - r["points_against"]
            print(f"{r['name']}: {r['wins']}W-{r['losses']}L (diff {diff:+d})")
    elif args.command == "leaderboard":
        for r in standings.leaderboard(db):
            print(f"{r['name']}: {r['points']} pts")

    store.save(db)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
