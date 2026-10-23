const http = require('node:http');
const https = require('node:https');

const PORT = Number(process.env.PORT || 8000);
const UPSTREAM = new URL(process.env.UPSTREAM_BASE || 'https://liuhe-api-330966-11-1509887168.sh.run.tcloudbase.com');

function json(res, status, body) {
  const data = Buffer.from(JSON.stringify(body));
  res.writeHead(status, {
    'content-type': 'application/json; charset=utf-8',
    'content-length': data.length,
    'cache-control': 'no-store'
  });
  res.end(data);
}

const server = http.createServer((req, res) => {
  if (req.url === '/healthz' || req.url === '/') {
    json(res, 200, { ok: true, service: 'liuhe-douyin-gateway', upstream: UPSTREAM.origin });
    return;
  }
  if (!req.url.startsWith('/api/')) {
    json(res, 404, { ok: false, error: 'NOT_FOUND' });
    return;
  }

  const headers = Object.assign({}, req.headers, {
    host: UPSTREAM.host,
    'x-forwarded-host': req.headers.host || '',
    'x-forwarded-proto': 'https'
  });
  delete headers.connection;

  const upstreamReq = https.request({
    protocol: UPSTREAM.protocol,
    hostname: UPSTREAM.hostname,
    port: UPSTREAM.port || 443,
    method: req.method,
    path: req.url,
    headers
  }, (upstreamRes) => {
    const responseHeaders = Object.assign({}, upstreamRes.headers);
    delete responseHeaders.connection;
    delete responseHeaders['transfer-encoding'];
    res.writeHead(upstreamRes.statusCode || 502, responseHeaders);
    upstreamRes.pipe(res);
  });

  upstreamReq.on('error', (error) => {
    if (!res.headersSent) {
      json(res, 502, { ok: false, error: 'UPSTREAM_UNAVAILABLE', message: error.message });
    } else {
      res.destroy();
    }
  });

  req.on('aborted', () => upstreamReq.destroy());
  req.pipe(upstreamReq);
});

server.listen(PORT, '0.0.0.0', () => {
  console.log('liuhe douyin gateway listening on ' + PORT);
});
