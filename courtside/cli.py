"""Command-line interface for CourtSide."""
from __future__ import annotations

import argparse

from . import store, teams, players


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

    store.save(db)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
