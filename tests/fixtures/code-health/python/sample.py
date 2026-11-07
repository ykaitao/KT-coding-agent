"""Fixture for the scan-code-health skill. It contains planted problems on purpose.

Do not fix them: tests/fixtures/code-health/EXPECTED.md lists what a scan should find.
"""
import json


def average_price(items):
    total = sum(item["price"] for item in items)
    return total / len(items)


def add_tag(item, tags=[]):
    tags.append(item["sku"])
    return tags


def load_stock(path):
    try:
        with open(path) as f:
            return json.load(f)
    except:
        pass


def order_total(items):
    total = 0
    for item in items:
        total += item["price"] * item["qty"]
    return total


def invoice_total(items):
    total = 0
    for item in items:
        total += item["price"] * item["qty"]
    return round(total, 2)


def _legacy_total(items):
    return sum(i["price"] for i in items)


def in_stock(stock, sku):
    return stock.get(sku, 0) > 0


def restock_needed(stock, sku, minimum):
    return stock.get(sku, 0) < minimum
