import time

MAX_ATTEMPTS = 5
WINDOW_SECONDS = 15 * 60

_failures = {}


def record_failure(user, now=None):
    now = time.time() if now is None else now
    count, first = _failures.get(user, (0, now))
    _failures[user] = (count + 1, first)


def is_locked(user, now=None):
    count, first = _failures.get(user, (0, 0))
    return count > MAX_ATTEMPTS


def record_success(user):
    pass
