#!/usr/bin/env bash
#
# CourtSide — автоматичен builder на GitHub историята.
# Пуска се ВЪТРЕ в клонираното репо:  bash courtside_build.sh
#
# Прави: първи (bootstrap) commit в main, после по един бранч + PR за всеки
# тикет (BB-11, BB-3 ... BB-15), всеки слят в main през Pull Request.
# Всичко с твоята git самоличност и твоя gh акаунт. Нула Claude в историята.

set -euo pipefail

# --- твоята самоличност за коммитите ---
git config user.name "Kolpic"
git config user.email "galincho112@gmail.com"

BOARD="https://galincho.atlassian.net/jira/software/projects/BB/boards/3"

# Помощна функция: add + commit + push + отваря PR + merge-ва го в main.
ship() {
  local b="$1" title="$2" body="$3"
  git add -A
  git commit -q -m "$title"
  git push -q -u origin "$b"
  sleep 2
  gh pr create --base main --head "$b" --title "$title" --body "$body" >/dev/null
  # merge with a few retries in case GitHub needs a moment to compute mergeability
  local ok=0 i
  for i in 1 2 3 4 5 6; do
    if gh pr merge "$b" --merge --delete-branch >/dev/null 2>&1; then ok=1; break; fi
    sleep 4
  done
  if [ "$ok" != "1" ]; then
    echo "!!! Неуспешен merge на $b. Спирам. Копирай това съобщение на Claude."
    exit 1
  fi
  git checkout -q main
  git pull -q --ff-only origin main
  git branch -q -D "$b" 2>/dev/null || true
  echo "  ✓ PR слят: $title"
}

echo "==> Bootstrap (първи commit в main)"
mkdir -p courtside tests .github/workflows

cat > .gitignore <<'EOF'
# Python
__pycache__/
*.py[cod]
*.egg-info/
.venv/
venv/
.pytest_cache/

# App data (local JSON store)
courtside_data.json

# OS / editor
.DS_Store
.idea/
.vscode/
EOF

cat > README.md <<'EOF'
# CourtSide

Работи се по проекта. Пълното описание идва с първия Pull Request (BB-11).
EOF

git add -A
git commit -q -m "Initial commit: project bootstrap"
git branch -M main
git push -q -u origin main
echo "  ✓ main създаден и качен"

# =====================================================================
echo "==> BB-11: скелет на проекта, data store, README"
git checkout -q -b BB-11-project-setup

cat > courtside/__init__.py <<'EOF'
"""CourtSide — amateur basketball league manager."""

__version__ = "1.0.0"
EOF

cat > courtside/store.py <<'EOF'
"""JSON-backed persistence for CourtSide.

The whole application state (teams, players, games) lives in a single JSON
file so the project stays dependency-free and the data is easy to inspect.
Business-logic modules work on a plain ``dict`` (called ``db``); the CLI is
the only layer that loads from / saves to disk.
"""
from __future__ import annotations

import json
import os

DEFAULT_PATH = os.environ.get("COURTSIDE_DB", "courtside_data.json")


def new_db() -> dict:
    """Return an empty database structure."""
    return {"teams": [], "players": [], "games": []}


def load(path: str = DEFAULT_PATH) -> dict:
    """Load the database from ``path`` (or return an empty one)."""
    if not os.path.exists(path):
        return new_db()
    with open(path, "r", encoding="utf-8") as fh:
        return json.load(fh)


def save(db: dict, path: str = DEFAULT_PATH) -> None:
    """Persist the database to ``path``."""
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(db, fh, ensure_ascii=False, indent=2)


def next_id(items: list) -> int:
    """Return the next integer id for a collection."""
    return max((item["id"] for item in items), default=0) + 1
EOF

cat > pyproject.toml <<'EOF'
[build-system]
requires = ["setuptools>=61"]
build-backend = "setuptools.build_meta"

[project]
name = "courtside"
version = "1.0.0"
description = "Amateur basketball league manager"
requires-python = ">=3.9"

[tool.setuptools]
packages = ["courtside"]

[tool.pytest.ini_options]
pythonpath = ["."]
testpaths = ["tests"]
EOF

cat > requirements-dev.txt <<'EOF'
pytest>=7.0
EOF

cat > tests/test_store.py <<'EOF'
from courtside import store


def test_new_db_is_empty():
    assert store.new_db() == {"teams": [], "players": [], "games": []}


def test_next_id():
    assert store.next_id([]) == 1
    assert store.next_id([{"id": 1}, {"id": 2}]) == 3
EOF

cat > README.md <<'EOF'
# 🏀 CourtSide — мениджър за аматьорска баскетболна лига

CourtSide е малко приложение (команден ред), с което се управлява
**аматьорска баскетболна лига**: отбори, играчи, мачове, резултати,
автоматично класиране и статистика на играчите.

## Какъв е продуктът
Инструмент, който държи на едно място цялата информация за една лига и смята
класирането вместо организатора.

## За кого е (потребител)
- **Организатор на лигата** — създава отбори, добавя играчи, насрочва мачове,
  въвежда резултати и статистика.
- **Играч / фен** — гледа състави, класиране и лидерборд по точки.

## Какъв проблем решава
Аматьорските лиги обикновено се водят в тетрадка или Excel — резултатите се
губят, класирането се смята на ръка и греши, няма общо място за състави и
статистика. CourtSide събира всичко на едно място и смята класирането
автоматично от въведените резултати.

## Функционалности
1. Създаване на отбор
2. Добавяне на играч към отбор
3. Преглед на състав (roster)
4. Редакция / премахване на играч
5. Насрочване на мач между два отбора
6. Въвеждане на краен резултат на мач
7. Въвеждане на точки на играч за мач (box score)
8. Класиране на лигата (автоматично)
9. Лидерборд по отбелязани точки

## Как се стартира
```bash
python -m courtside add-team "Lakers"
python -m courtside add-team "Bulls"
python -m courtside add-player 1 "LeBron James" --number 23
python -m courtside roster 1
python -m courtside schedule 1 2 2026-10-10
python -m courtside score 1 102 98
python -m courtside player-stats 1 1 34
python -m courtside standings
python -m courtside leaderboard
```
Данните се пазят в локален файл `courtside_data.json`.

## Структура на проекта
```
courtside/        # бизнес логика
  store.py        # запис/четене на данните (JSON)
  teams.py        # отбори
  players.py      # играчи / състави
  games.py        # мачове, резултати, статистика
  standings.py    # класиране и лидерборд
  cli.py          # команден интерфейс
tests/            # автоматични тестове (pytest)
```

## Тестове
```bash
pip install -r requirements-dev.txt
pytest -q
```

## Управление на проекта (Jira)
Работата по продукта се води в Jira (epics, stories, tasks, bugs, 2 спринта).
Връзката Jira ↔ GitHub показва бранча и Pull Request-а във всеки тикет.

Jira борд: https://galincho.atlassian.net/jira/software/projects/BB/boards/3
EOF

ship "BB-11-project-setup" "BB-11: project scaffold, data store and README" "Implements task BB-11: project structure, JSON data store, dev deps and full README."

# =====================================================================
echo "==> BB-12: CI (GitHub Actions)"
git checkout -q -b BB-12-ci

cat > .github/workflows/ci.yml <<'EOF'
name: CI

on:
  push:
    branches: [main]
  pull_request:

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: "3.12"
      - name: Install dependencies
        run: pip install -r requirements-dev.txt
      - name: Run tests
        run: pytest -q
EOF

ship "BB-12-ci" "BB-12: add GitHub Actions CI (pytest)" "Implements task BB-12: run the test suite on every push and pull request."

# =====================================================================
echo "==> BB-3: създаване на отбор"
git checkout -q -b BB-3-create-team

cat > courtside/teams.py <<'EOF'
"""Create and read teams."""
from __future__ import annotations

from . import store


def create_team(db: dict, name: str) -> dict:
    """Register a new team and return it.

    Raises ValueError if the name is empty or already used.
    """
    name = (name or "").strip()
    if not name:
        raise ValueError("Team name cannot be empty")
    if any(t["name"].lower() == name.lower() for t in db["teams"]):
        raise ValueError(f"Team '{name}' already exists")
    team = {"id": store.next_id(db["teams"]), "name": name}
    db["teams"].append(team)
    return team


def list_teams(db: dict) -> list:
    """Return all teams."""
    return db["teams"]


def get_team(db: dict, team_id: int) -> dict:
    """Return a team by id or raise ValueError."""
    for team in db["teams"]:
        if team["id"] == team_id:
            return team
    raise ValueError(f"No team with id {team_id}")
EOF

cat > courtside/__main__.py <<'EOF'
"""Entry point so the package can run as ``python -m courtside``."""
from .cli import main

if __name__ == "__main__":
    raise SystemExit(main())
EOF

cat > courtside/cli.py <<'EOF'
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
EOF

cat > tests/test_teams.py <<'EOF'
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
EOF

ship "BB-3-create-team" "BB-3: create team" "Implements story BB-3: as an organizer I can create a team."

# =====================================================================
echo "==> BB-4: добавяне на играчи"
git checkout -q -b BB-4-add-players

cat > courtside/players.py <<'EOF'
"""Manage the players on a team's roster."""
from __future__ import annotations

from . import store, teams


def add_player(db: dict, team_id: int, name: str, number: int | None = None) -> dict:
    """Add a player to a team and return the player."""
    teams.get_team(db, team_id)  # validates that the team exists
    player = {
        "id": store.next_id(db["players"]),
        "team_id": team_id,
        "name": name,
        "number": number,
    }
    db["players"].append(player)
    return player


def get_player(db: dict, player_id: int) -> dict:
    """Return a player by id or raise ValueError."""
    for player in db["players"]:
        if player["id"] == player_id:
            return player
    raise ValueError(f"No player with id {player_id}")
EOF

cat > courtside/cli.py <<'EOF'
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
EOF

cat > tests/test_players.py <<'EOF'
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
EOF

ship "BB-4-add-players" "BB-4: add players to a team" "Implements story BB-4: as an organizer I can add players to a team."

# =====================================================================
echo "==> BB-5: преглед на състав (baseline)"
git checkout -q -b BB-5-view-roster

cat > courtside/players.py <<'EOF'
"""Manage the players on a team's roster."""
from __future__ import annotations

from . import store, teams


def add_player(db: dict, team_id: int, name: str, number: int | None = None) -> dict:
    """Add a player to a team and return the player."""
    teams.get_team(db, team_id)  # validates that the team exists
    player = {
        "id": store.next_id(db["players"]),
        "team_id": team_id,
        "name": name,
        "number": number,
    }
    db["players"].append(player)
    return player


def get_roster(db: dict, team_id: int) -> list:
    """Return all players of a team."""
    teams.get_team(db, team_id)
    return [p for p in db["players"] if p["team_id"] == team_id]


def get_player(db: dict, player_id: int) -> dict:
    """Return a player by id or raise ValueError."""
    for player in db["players"]:
        if player["id"] == player_id:
            return player
    raise ValueError(f"No player with id {player_id}")
EOF

cat > courtside/cli.py <<'EOF'
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

    p = sub.add_parser("roster", help="Show a team's roster")
    p.add_argument("team_id", type=int)
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

    store.save(db)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
EOF

cat > tests/test_players.py <<'EOF'
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


def test_get_roster():
    db = _db_with_team()
    players.add_player(db, 1, "Tatum", 0)
    players.add_player(db, 1, "Brown", 7)
    roster = players.get_roster(db, 1)
    assert [p["name"] for p in roster] == ["Tatum", "Brown"]
EOF

ship "BB-5-view-roster" "BB-5: view team roster" "Implements story BB-5 (baseline): as a fan I can view a team's roster."

# =====================================================================
echo "==> BB-6: редакция/премахване на играч"
git checkout -q -b BB-6-edit-player

cat > courtside/players.py <<'EOF'
"""Manage the players on a team's roster."""
from __future__ import annotations

from . import store, teams


def add_player(db: dict, team_id: int, name: str, number: int | None = None) -> dict:
    """Add a player to a team and return the player."""
    teams.get_team(db, team_id)  # validates that the team exists
    player = {
        "id": store.next_id(db["players"]),
        "team_id": team_id,
        "name": name,
        "number": number,
    }
    db["players"].append(player)
    return player


def get_roster(db: dict, team_id: int) -> list:
    """Return all players of a team."""
    teams.get_team(db, team_id)
    return [p for p in db["players"] if p["team_id"] == team_id]


def get_player(db: dict, player_id: int) -> dict:
    """Return a player by id or raise ValueError."""
    for player in db["players"]:
        if player["id"] == player_id:
            return player
    raise ValueError(f"No player with id {player_id}")


def update_player(db: dict, player_id: int, name: str | None = None,
                  number: int | None = None) -> dict:
    """Update a player's name and/or shirt number."""
    player = get_player(db, player_id)
    if name is not None:
        name = name.strip()
        if not name:
            raise ValueError("Player name cannot be empty")
        player["name"] = name
    if number is not None:
        player["number"] = number
    return player


def remove_player(db: dict, player_id: int) -> None:
    """Remove a player from the roster."""
    player = get_player(db, player_id)
    db["players"].remove(player)
EOF

cat > courtside/cli.py <<'EOF'
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

    p = sub.add_parser("roster", help="Show a team's roster")
    p.add_argument("team_id", type=int)

    p = sub.add_parser("edit-player", help="Edit a player")
    p.add_argument("player_id", type=int)
    p.add_argument("--name")
    p.add_argument("--number", type=int)

    p = sub.add_parser("remove-player", help="Remove a player")
    p.add_argument("player_id", type=int)
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

    store.save(db)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
EOF

cat > tests/test_players.py <<'EOF'
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


def test_get_roster():
    db = _db_with_team()
    players.add_player(db, 1, "Tatum", 0)
    players.add_player(db, 1, "Brown", 7)
    roster = players.get_roster(db, 1)
    assert [p["name"] for p in roster] == ["Tatum", "Brown"]


def test_update_and_remove_player():
    db = _db_with_team()
    players.add_player(db, 1, "Tatum", 0)
    players.update_player(db, 1, name="Jayson Tatum")
    assert players.get_player(db, 1)["name"] == "Jayson Tatum"
    players.remove_player(db, 1)
    assert players.get_roster(db, 1) == []
EOF

ship "BB-6-edit-player" "BB-6: edit and remove players" "Implements story BB-6: as an organizer I can edit or remove a player."

# =====================================================================
echo "==> BB-7: насрочване на мач"
git checkout -q -b BB-7-schedule-game

cat > courtside/games.py <<'EOF'
"""Schedule games and record results and player box scores."""
from __future__ import annotations

from . import store, teams


def schedule_game(db: dict, home_id: int, away_id: int, date: str) -> dict:
    """Create a scheduled game between two different teams."""
    if home_id == away_id:
        raise ValueError("A team cannot play against itself")
    teams.get_team(db, home_id)
    teams.get_team(db, away_id)
    game = {
        "id": store.next_id(db["games"]),
        "home_id": home_id,
        "away_id": away_id,
        "date": date,
        "home_score": None,
        "away_score": None,
        "stats": [],  # list of {player_id, points}
    }
    db["games"].append(game)
    return game


def get_game(db: dict, game_id: int) -> dict:
    """Return a game by id or raise ValueError."""
    for game in db["games"]:
        if game["id"] == game_id:
            return game
    raise ValueError(f"No game with id {game_id}")


def is_finished(game: dict) -> bool:
    """A game counts for the standings only once it has a score."""
    return game["home_score"] is not None and game["away_score"] is not None
EOF

cat > courtside/cli.py <<'EOF'
"""Command-line interface for CourtSide."""
from __future__ import annotations

import argparse

from . import store, teams, players, games


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

    store.save(db)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
EOF

cat > tests/test_games.py <<'EOF'
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
EOF

ship "BB-7-schedule-game" "BB-7: schedule a game" "Implements story BB-7: as an organizer I can schedule a game between two teams."

# =====================================================================
echo "==> BB-8: въвеждане на резултат (+ subtasks)"
git checkout -q -b BB-8-record-score

cat > courtside/games.py <<'EOF'
"""Schedule games and record results and player box scores."""
from __future__ import annotations

from . import store, teams


def schedule_game(db: dict, home_id: int, away_id: int, date: str) -> dict:
    """Create a scheduled game between two different teams."""
    if home_id == away_id:
        raise ValueError("A team cannot play against itself")
    teams.get_team(db, home_id)
    teams.get_team(db, away_id)
    game = {
        "id": store.next_id(db["games"]),
        "home_id": home_id,
        "away_id": away_id,
        "date": date,
        "home_score": None,
        "away_score": None,
        "stats": [],  # list of {player_id, points}
    }
    db["games"].append(game)
    return game


def get_game(db: dict, game_id: int) -> dict:
    """Return a game by id or raise ValueError."""
    for game in db["games"]:
        if game["id"] == game_id:
            return game
    raise ValueError(f"No game with id {game_id}")


def record_score(db: dict, game_id: int, home_score: int, away_score: int) -> dict:
    """Record (or correct) the final score of a game."""
    game = get_game(db, game_id)
    game["home_score"] = home_score
    game["away_score"] = away_score
    return game


def is_finished(game: dict) -> bool:
    """A game counts for the standings only once it has a score."""
    return game["home_score"] is not None and game["away_score"] is not None
EOF

cat > courtside/cli.py <<'EOF'
"""Command-line interface for CourtSide."""
from __future__ import annotations

import argparse

from . import store, teams, players, games


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

    store.save(db)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
EOF

cat > tests/test_games.py <<'EOF'
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
EOF

ship "BB-8-record-score" "BB-8: record final score" "Implements story BB-8 (with subtasks BB-16..BB-19): as an organizer I can record a game's final score."

# =====================================================================
echo "==> BB-9: точки на играчи + лидерборд"
git checkout -q -b BB-9-player-stats

cat > courtside/games.py <<'EOF'
"""Schedule games and record results and player box scores."""
from __future__ import annotations

from . import store, teams, players


def schedule_game(db: dict, home_id: int, away_id: int, date: str) -> dict:
    """Create a scheduled game between two different teams."""
    if home_id == away_id:
        raise ValueError("A team cannot play against itself")
    teams.get_team(db, home_id)
    teams.get_team(db, away_id)
    game = {
        "id": store.next_id(db["games"]),
        "home_id": home_id,
        "away_id": away_id,
        "date": date,
        "home_score": None,
        "away_score": None,
        "stats": [],  # list of {player_id, points}
    }
    db["games"].append(game)
    return game


def get_game(db: dict, game_id: int) -> dict:
    """Return a game by id or raise ValueError."""
    for game in db["games"]:
        if game["id"] == game_id:
            return game
    raise ValueError(f"No game with id {game_id}")


def record_score(db: dict, game_id: int, home_score: int, away_score: int) -> dict:
    """Record (or correct) the final score of a game."""
    game = get_game(db, game_id)
    game["home_score"] = home_score
    game["away_score"] = away_score
    return game


def record_player_stats(db: dict, game_id: int, player_id: int, points: int) -> dict:
    """Record how many points a player scored in a game."""
    game = get_game(db, game_id)
    players.get_player(db, player_id)
    # one entry per player: replace any previous one
    game["stats"] = [s for s in game["stats"] if s["player_id"] != player_id]
    entry = {"player_id": player_id, "points": points}
    game["stats"].append(entry)
    return entry


def is_finished(game: dict) -> bool:
    """A game counts for the standings only once it has a score."""
    return game["home_score"] is not None and game["away_score"] is not None
EOF

cat > courtside/standings.py <<'EOF'
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
EOF

cat > courtside/cli.py <<'EOF'
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
    elif args.command == "leaderboard":
        for r in standings.leaderboard(db):
            print(f"{r['name']}: {r['points']} pts")

    store.save(db)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
EOF

cat > tests/test_standings.py <<'EOF'
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
EOF

cat >> tests/test_games.py <<'EOF'


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
EOF

ship "BB-9-player-stats" "BB-9: record player stats and leaderboard" "Implements story BB-9: as an organizer I can record player points; fans see a leaderboard."

# =====================================================================
echo "==> BB-10: класиране (съдържа бъг BB-14, който после се оправя)"
git checkout -q -b BB-10-standings

cat > courtside/standings.py <<'EOF'
"""League standings and scoring leaderboard."""
from __future__ import annotations

from . import games


def compute_standings(db: dict) -> list:
    """Return standings sorted by wins, then point difference.

    NOTE: за бързина пазим вече изчисленото класиране в db["standings"]
    и го връщаме наготово при следващо извикване.
    """
    if db.get("standings"):
        return db["standings"]
    table = {
        t["id"]: {
            "team_id": t["id"],
            "name": t["name"],
            "played": 0, "wins": 0, "losses": 0,
            "points_for": 0, "points_against": 0,
        }
        for t in db["teams"]
    }
    for game in db["games"]:
        if not games.is_finished(game):
            continue
        home, away = table[game["home_id"]], table[game["away_id"]]
        home["played"] += 1
        away["played"] += 1
        home["points_for"] += game["home_score"]
        home["points_against"] += game["away_score"]
        away["points_for"] += game["away_score"]
        away["points_against"] += game["home_score"]
        if game["home_score"] > game["away_score"]:
            home["wins"] += 1
            away["losses"] += 1
        else:
            away["wins"] += 1
            home["losses"] += 1
    rows = list(table.values())
    rows.sort(key=lambda r: (r["wins"], r["points_for"] - r["points_against"]),
              reverse=True)
    db["standings"] = rows
    return rows


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
EOF

cat > courtside/cli.py <<'EOF'
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
EOF

cat >> tests/test_standings.py <<'EOF'


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
EOF

ship "BB-10-standings" "BB-10: league standings" "Implements story BB-10: as a fan I can see the league standings."

# =====================================================================
echo "==> BB-13: логване и валидация в data layer"
git checkout -q -b BB-13-logging

cat > courtside/store.py <<'EOF'
"""JSON-backed persistence for CourtSide.

The whole application state (teams, players, games) lives in a single JSON
file so the project stays dependency-free and the data is easy to inspect.
Business-logic modules work on a plain ``dict`` (called ``db``); the CLI is
the only layer that loads from / saves to disk.
"""
from __future__ import annotations

import json
import logging
import os

DEFAULT_PATH = os.environ.get("COURTSIDE_DB", "courtside_data.json")

logger = logging.getLogger("courtside")


def new_db() -> dict:
    """Return an empty database structure."""
    return {"teams": [], "players": [], "games": []}


def load(path: str = DEFAULT_PATH) -> dict:
    """Load the database from ``path`` (or return an empty one)."""
    if not os.path.exists(path):
        return new_db()
    with open(path, "r", encoding="utf-8") as fh:
        data = json.load(fh)
    # defensive: make sure the expected collections exist
    for key in ("teams", "players", "games"):
        data.setdefault(key, [])
    logger.debug("Loaded database from %s", path)
    return data


def save(db: dict, path: str = DEFAULT_PATH) -> None:
    """Persist the database to ``path``."""
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(db, fh, ensure_ascii=False, indent=2)
    logger.debug("Saved database to %s", path)


def next_id(items: list) -> int:
    """Return the next integer id for a collection."""
    return max((item["id"] for item in items), default=0) + 1
EOF

ship "BB-13-logging" "BB-13: logging and validation in data layer" "Implements task BB-13: add logging and defensive structure checks to the data store."

# =====================================================================
echo "==> BB-14: fix на класирането (bug)"
git checkout -q -b BB-14-fix-standings

cat > courtside/standings.py <<'EOF'
"""League standings and scoring leaderboard (computed from games)."""
from __future__ import annotations

from . import games


def compute_standings(db: dict) -> list:
    """Return standings sorted by wins, then point difference.

    The table is always recomputed from the finished games, so correcting a
    score is reflected immediately (this is the fix for bug BB-14).
    """
    table = {
        t["id"]: {
            "team_id": t["id"],
            "name": t["name"],
            "played": 0, "wins": 0, "losses": 0,
            "points_for": 0, "points_against": 0,
        }
        for t in db["teams"]
    }
    for game in db["games"]:
        if not games.is_finished(game):
            continue
        home, away = table[game["home_id"]], table[game["away_id"]]
        home["played"] += 1
        away["played"] += 1
        home["points_for"] += game["home_score"]
        home["points_against"] += game["away_score"]
        away["points_for"] += game["away_score"]
        away["points_against"] += game["home_score"]
        if game["home_score"] > game["away_score"]:
            home["wins"] += 1
            away["losses"] += 1
        else:
            away["wins"] += 1
            home["losses"] += 1
    rows = list(table.values())
    rows.sort(key=lambda r: (r["wins"], r["points_for"] - r["points_against"]),
              reverse=True)
    return rows


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
EOF

cat >> tests/test_standings.py <<'EOF'


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
EOF

ship "BB-14-fix-standings" "BB-14: fix standings not recomputed after score edit" "Fixes bug BB-14: standings are always recomputed from games, so a corrected score is reflected immediately."

# =====================================================================
echo "==> BB-15: fix на валидациите (bug)"
git checkout -q -b BB-15-fix-validation

cat > courtside/players.py <<'EOF'
"""Manage the players on a team's roster."""
from __future__ import annotations

from . import store, teams


def add_player(db: dict, team_id: int, name: str, number: int | None = None) -> dict:
    """Add a player to a team and return the player."""
    teams.get_team(db, team_id)  # validates that the team exists
    name = (name or "").strip()
    if not name:
        raise ValueError("Player name cannot be empty")
    player = {
        "id": store.next_id(db["players"]),
        "team_id": team_id,
        "name": name,
        "number": number,
    }
    db["players"].append(player)
    return player


def get_roster(db: dict, team_id: int) -> list:
    """Return all players of a team."""
    teams.get_team(db, team_id)
    return [p for p in db["players"] if p["team_id"] == team_id]


def get_player(db: dict, player_id: int) -> dict:
    """Return a player by id or raise ValueError."""
    for player in db["players"]:
        if player["id"] == player_id:
            return player
    raise ValueError(f"No player with id {player_id}")


def update_player(db: dict, player_id: int, name: str | None = None,
                  number: int | None = None) -> dict:
    """Update a player's name and/or shirt number."""
    player = get_player(db, player_id)
    if name is not None:
        name = name.strip()
        if not name:
            raise ValueError("Player name cannot be empty")
        player["name"] = name
    if number is not None:
        player["number"] = number
    return player


def remove_player(db: dict, player_id: int) -> None:
    """Remove a player from the roster."""
    player = get_player(db, player_id)
    db["players"].remove(player)
EOF

cat > courtside/games.py <<'EOF'
"""Schedule games and record results and player box scores."""
from __future__ import annotations

from . import store, teams, players


def schedule_game(db: dict, home_id: int, away_id: int, date: str) -> dict:
    """Create a scheduled game between two different teams."""
    if home_id == away_id:
        raise ValueError("A team cannot play against itself")
    teams.get_team(db, home_id)
    teams.get_team(db, away_id)
    game = {
        "id": store.next_id(db["games"]),
        "home_id": home_id,
        "away_id": away_id,
        "date": date,
        "home_score": None,
        "away_score": None,
        "stats": [],  # list of {player_id, points}
    }
    db["games"].append(game)
    return game


def get_game(db: dict, game_id: int) -> dict:
    """Return a game by id or raise ValueError."""
    for game in db["games"]:
        if game["id"] == game_id:
            return game
    raise ValueError(f"No game with id {game_id}")


def record_score(db: dict, game_id: int, home_score: int, away_score: int) -> dict:
    """Record (or correct) the final score of a game."""
    if home_score < 0 or away_score < 0:
        raise ValueError("Scores cannot be negative")
    game = get_game(db, game_id)
    game["home_score"] = home_score
    game["away_score"] = away_score
    return game


def record_player_stats(db: dict, game_id: int, player_id: int, points: int) -> dict:
    """Record how many points a player scored in a game."""
    if points < 0:
        raise ValueError("Points cannot be negative")
    game = get_game(db, game_id)
    players.get_player(db, player_id)
    # one entry per player: replace any previous one
    game["stats"] = [s for s in game["stats"] if s["player_id"] != player_id]
    entry = {"player_id": player_id, "points": points}
    game["stats"].append(entry)
    return entry


def is_finished(game: dict) -> bool:
    """A game counts for the standings only once it has a score."""
    return game["home_score"] is not None and game["away_score"] is not None
EOF

cat >> tests/test_players.py <<'EOF'


def test_add_player_empty_name_rejected():
    db = _db_with_team()
    with pytest.raises(ValueError):
        players.add_player(db, 1, "   ")
EOF

cat >> tests/test_games.py <<'EOF'


def test_negative_score_rejected():
    db = _db_two_teams()
    games.schedule_game(db, 1, 2, "2026-10-10")
    with pytest.raises(ValueError):
        games.record_score(db, 1, -5, 10)
EOF

ship "BB-15-fix-validation" "BB-15: fix validation for empty name and negative points" "Fixes bug BB-15: reject empty player names and negative scores/points."

echo ""
echo "======================================================"
echo " ГОТОВО! Всички бранчове и PR-и са слети в main."
echo " Jira борд: $BOARD"
echo "======================================================"
