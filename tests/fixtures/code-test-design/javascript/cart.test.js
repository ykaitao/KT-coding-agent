const test = require("node:test");
const assert = require("node:assert");
const { addItem, removeItem, shippingFee } = require("./cart");

let shared = [];

test("adds an item", () => {
  shared = addItem(shared, { sku: "a", price: 5 });
  assert.strictEqual(shared.length, 1);
});

test("cart keeps the added item", () => {
  assert.strictEqual(shared[0].sku, "a");
});

test("removes an item", () => {
  const cart = [{ sku: "a", price: 5 }];
  removeItem(cart, "a");
  assert.strictEqual(cart.length, 1);
});

test("shipping is free for large orders and paid for small ones", () => {
  assert.strictEqual(shippingFee(100), 0);
  assert.strictEqual(shippingFee(10), 5);
});
