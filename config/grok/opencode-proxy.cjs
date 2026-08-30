// OpenCode Zen Stream Filter & Reasoning Sanitizer Proxy
//
// Solves two critical upstream incompatibilities between OpenCode Zen (Muse Spark)
// and the compiled Rust Grok CLI (`grok.exe`):
//
// 1. Rust Serde SSE enum deserialization:
//    OpenCode Zen injects non-standard `event: ping` keepalive/cost frames into
//    `/v1/responses` SSE streams. Grok CLI's Rust parser expects strict OpenAI
//    Responses events (`response.created`, `response.completed`, etc.) and panics
//    with "unknown variant `ping`". This proxy discards ping frames on the fly.
//
// 2. Cross-turn reasoning history rejection:
//    In multi-turn sessions, Grok CLI sends previous output items in the `input`
//    array. OpenCode Zen rejects requests containing prior `type: "reasoning"` items
//    with HTTP 400 "Invalid reasoning item id format. Expected an id returned on a
//    reasoning output item." This proxy sanitizes the input array before forwarding.

const http = require('http');
const https = require('https');
const fs = require('fs');

const TARGET_HOST = 'opencode.ai';
const PORT = 5210;

const server = http.createServer((clientReq, clientRes) => {
  let subPath = clientReq.url;
  if (subPath.startsWith('/v1')) {
    subPath = subPath.slice(3);
  }

  const headers = { ...clientReq.headers, host: TARGET_HOST };

  // STRICT SECURITY: Unconditionally inject real API key over the dummy key from config
  const envKey = process.env.OPENCODE_API_KEY;
  if (envKey) {
    headers['authorization'] = `Bearer ${envKey}`;
  }

  // Buffer request body to sanitize multi-turn history & determine dynamic routing
  const reqChunks = [];
  clientReq.on('data', chunk => reqChunks.push(chunk));
  clientReq.on('end', () => {
    let finalBody = Buffer.concat(reqChunks);
    let targetPath = '/zen/go/v1' + subPath; // Default to Go subscription

    if (finalBody.length > 0) {
      try {
        const json = JSON.parse(finalBody.toString('utf8'));
        let modified = false;

        // DYNAMIC ROUTING: Route -free models to the standard Zen API
        if (json.model && typeof json.model === 'string') {
          if (json.model.includes('-free')) {
            targetPath = '/zen/v1' + subPath;
          }
        }

        // Strip prior reasoning items from input history to prevent HTTP 400
        if (Array.isArray(json.input)) {
          const originalLen = json.input.length;
          json.input = json.input.filter(item => {
            if (!item) return false;
            if (item.type === 'reasoning') return false;
            if (item.type === 'item_reference' && typeof item.id === 'string' && item.id.startsWith('rs_')) {
              return false;
            }
            return true;
          });

          if (json.input.length !== originalLen) {
            modified = true;
          }
        }

        if (modified) {
          finalBody = Buffer.from(JSON.stringify(json));
          headers['content-length'] = Buffer.byteLength(finalBody);
        }
      } catch (e) {
        // Non-JSON or parse error; forward untouched
      }
    }

    const options = {
      hostname: TARGET_HOST,
      port: 443,
      path: targetPath,
      method: clientReq.method,
      headers: headers
    };

    const proxyReq = https.request(options, (proxyRes) => {
      const contentType = proxyRes.headers['content-type'] || '';
      const isSSE = contentType.includes('text/event-stream');

      if (!isSSE) {
        clientRes.writeHead(proxyRes.statusCode, proxyRes.headers);
        proxyRes.pipe(clientRes);
        return;
      }

      clientRes.writeHead(proxyRes.statusCode, proxyRes.headers);

      let buffer = '';
      proxyRes.on('data', (chunk) => {
        buffer += chunk.toString('utf8');
        const parts = buffer.split('\n\n');
        buffer = parts.pop();

        for (const part of parts) {
          if (!part.trim()) continue;
          // Filter out OpenCode non-standard ping SSE frames
          if (/^event:\s*ping/m.test(part) || /"type":\s*"ping"/m.test(part)) {
            continue;
          }
          clientRes.write(part + '\n\n');
        }
      });

      proxyRes.on('end', () => {
        if (buffer.trim()) {
          if (!(/^event:\s*ping/m.test(buffer) || /"type":\s*"ping"/m.test(buffer))) {
            clientRes.write(buffer + '\n\n');
          }
        }
        clientRes.end();
      });
    });

    proxyReq.on('error', (err) => {
      clientRes.writeHead(502, { 'Content-Type': 'application/json' });
      clientRes.end(JSON.stringify({ error: err.message }));
    });

    proxyReq.write(finalBody);
    proxyReq.end();
  });
});

server.listen(PORT, '127.0.0.1', () => {
  console.log(`OpenCode Zen Filter Proxy listening on http://127.0.0.1:${PORT}`);
});
