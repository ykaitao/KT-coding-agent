// Fixture for the scan-code-health skill. It contains planted problems on purpose.
// Do not fix them: tests/fixtures/code-health/EXPECTED.md lists what a scan should find.
const fs = require("fs");

function averageScore(scores) {
  const total = scores.reduce((sum, s) => sum + s, 0);
  return total / scores.length;
}

function loadConfig(path) {
  try {
    return JSON.parse(fs.readFileSync(path, "utf8"));
  } catch (err) {
    return {};
  }
}

function cartTotal(lines) {
  let total = 0;
  for (const line of lines) {
    total += line.price * line.qty;
  }
  return total;
}

function receiptTotal(lines) {
  let total = 0;
  for (const line of lines) {
    total += line.price * line.qty;
  }
  return Math.round(total * 100) / 100;
}

function legacyDiscount(total) {
  return total * 0.9;
}

function isEmptyCart(lines) {
  return lines.length === 0;
}

function maxQty(lines) {
  return lines.reduce((max, line) => Math.max(max, line.qty), 0);
}

module.exports = { averageScore, loadConfig, cartTotal, receiptTotal, isEmptyCart, maxQty };
