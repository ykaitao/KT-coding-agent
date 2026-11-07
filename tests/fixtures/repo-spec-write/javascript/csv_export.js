function toCsv(rows) {
  if (rows.length === 0) {
    return "";
  }
  const header = Object.keys(rows[0]).join(",");
  const lines = rows.map((row) => Object.values(row).join(","));
  return [header, ...lines].join("\n");
}

module.exports = { toCsv };
