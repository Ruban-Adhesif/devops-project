const http = require("http");

const port = process.env.PORT || 3000;

function handler(req, res) {
  if (req.method === "GET" && req.url === "/health") {
    res.statusCode = 200;
    res.setHeader("Content-Type", "text/plain");
    res.end("OK");
    return;
  }

  res.statusCode = 404;
  res.end("Not found");
}

function createServer() {
  return http.createServer(handler);
}

if (require.main === module) {
  createServer().listen(port, () => {
    console.log("listening on port " + port);
  });
}

module.exports = { createServer };
