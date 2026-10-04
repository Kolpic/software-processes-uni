"""Command-line interface for CourtSide."""
from __future__ import annotations

import argparse

from . import store, teams


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="courtside", description="Amateur basketball league manager")
    sub = parser.add_subparsers(dest="command", required=True)

    p = sub.add_parser("add-team", help="Create a team")
    p.add_argument("name")

    sub.add_parser("list-teams", help="List all teams")
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

    store.save(db)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
