from courtside import store


def test_new_db_is_empty():
    assert store.new_db() == {"teams": [], "players": [], "games": []}


def test_next_id():
    assert store.next_id([]) == 1
    assert store.next_id([{"id": 1}, {"id": 2}]) == 3
