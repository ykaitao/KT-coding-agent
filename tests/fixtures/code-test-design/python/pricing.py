import time


def subtotal(items):
    return sum(item["price"] * item["qty"] for item in items)


def apply_discount(total, code):
    if code == "SAVE10":
        return round(total * 0.9, 2)
    if code == "HALF":
        return round(total * 0.5, 2)
    return total


def is_expired(expires_at, now=None):
    now = time.time() if now is None else now
    return now >= expires_at
