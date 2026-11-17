const test = require("node:test");
const assert = require("node:assert");
const { createServer } = require("./server");

test("GET /health returns OK", async () => {
  const server = createServer();

  await new Promise((resolve) => server.listen(0, resolve));
  const port = server.address().port;

  const res = await fetch("http://127.0.0.1:" + port + "/health");
  const body = await res.text();

  assert.strictEqual(res.status, 200);
  assert.strictEqual(body, "OK");

  server.close();
});
