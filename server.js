const http = require("http");
const client = require("prom-client");

const port = process.env.PORT || 3000;

client.collectDefaultMetrics();

const httpRequests = new client.Counter({
  name: "http_requests_total",
  help: "Total HTTP requests",
  labelNames: ["method", "route", "status"],
});

const httpDuration = new client.Histogram({
  name: "http_request_duration_seconds",
  help: "Request latency in seconds",
  labelNames: ["method", "route"],
  buckets: [0.05, 0.1, 0.3, 0.5, 1, 2],
});

const knownRoutes = new Set(["/", "/health", "/metrics", "/slow", "/error"]);

function routeOf(url) {
  const path = (url || "/").split("?")[0];
  return knownRoutes.has(path) ? path : "other";
}

function logRequest(req, res, route) {
  console.log(JSON.stringify({
    timestamp: new Date().toISOString(),
    level: res.statusCode >= 500 ? "error" : "info",
    method: req.method,
    path: route,
    status: res.statusCode,
  }));
}

function handler(req, res) {
  const route = routeOf(req.url);
  const end = httpDuration.startTimer({ method: req.method, route });

  res.on("finish", () => {
    httpRequests.inc({
      method: req.method,
      route,
      status: String(res.statusCode),
    });
    end();
    logRequest(req, res, route);
  });

  if (req.method === "GET" && route === "/health") {
    res.statusCode = 200;
    res.setHeader("Content-Type", "text/plain");
    res.end("OK v2");
    return;
  }

  if (req.method === "GET" && route === "/metrics") {
    client.register.metrics().then((body) => {
      res.statusCode = 200;
      res.setHeader("Content-Type", client.register.contentType);
      res.end(body);
    }).catch(() => {
      res.statusCode = 500;
      res.end("metrics unavailable");
    });
    return;
  }

  if (req.method === "GET" && route === "/slow") {
    const delayMs = Math.floor(Math.random() * 2000);
    setTimeout(() => {
      res.statusCode = 200;
      res.setHeader("Content-Type", "application/json");
      res.end(JSON.stringify({ delayMs }));
    }, delayMs);
    return;
  }

  if (req.method === "GET" && route === "/error") {
    const failed = Math.random() < 0.3;
    res.statusCode = failed ? 500 : 200;
    res.setHeader("Content-Type", "application/json");
    res.end(JSON.stringify({ ok: !failed }));
    return;
  }

  res.statusCode = 404;
  res.setHeader("Content-Type", "text/plain");
  res.end("Not found");
}

function createServer() {
  return http.createServer(handler);
}

if (require.main === module) {
  createServer().listen(port, () => {
    console.log(JSON.stringify({
      timestamp: new Date().toISOString(),
      level: "info",
      message: "listening",
      port: Number(port),
    }));
  });
}

module.exports = { createServer };
