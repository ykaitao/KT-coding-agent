function addItem(cart, item) {
  return [...cart, item];
}

function removeItem(cart, sku) {
  return cart.filter((item) => item.sku !== sku);
}

function total(cart) {
  return cart.reduce((sum, item) => sum + item.price, 0);
}

function shippingFee(orderTotal) {
  return orderTotal >= 50 ? 0 : 5;
}

module.exports = { addItem, removeItem, total, shippingFee };
