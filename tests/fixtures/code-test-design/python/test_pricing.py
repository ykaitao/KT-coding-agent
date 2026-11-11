import time

from pricing import apply_discount, is_expired, subtotal


def test_subtotal():
    assert subtotal([{"price": 2, "qty": 3}, {"price": 5, "qty": 1}]) == 11


def test_save10_discount():
    assert apply_discount(100, "SAVE10")


def test_expiry():
    expires_at = time.time() + 0.05
    time.sleep(0.05)
    assert is_expired(expires_at)


def test_not_expired_before_deadline():
    assert not is_expired(1000, now=999)
