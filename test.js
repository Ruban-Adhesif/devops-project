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
  assert.strictEqual(body, "OK v2");

  server.close();
});

test("GET /metrics exposes http_requests_total", async () => {
  const server = createServer();

  await new Promise((resolve) => server.listen(0, resolve));
  const port = server.address().port;

  const res = await fetch("http://127.0.0.1:" + port + "/metrics");
  const body = await res.text();

  assert.strictEqual(res.status, 200);
  assert.match(body, /http_requests_total/);
  assert.match(body, /http_request_duration_seconds/);

  server.close();
});

test("GET /error returns 200 or 500", async () => {
  const server = createServer();

  await new Promise((resolve) => server.listen(0, resolve));
  const port = server.address().port;

  const res = await fetch("http://127.0.0.1:" + port + "/error");
  assert.ok(res.status === 200 || res.status === 500);

  server.close();
});
