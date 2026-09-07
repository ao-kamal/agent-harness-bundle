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
const crypto = require('crypto');

function resolveSessionId(clientHeaders, jsonBody) {
  if (clientHeaders['x-opencode-session']) return clientHeaders['x-opencode-session'];
  if (clientHeaders['x-grok-session-id']) return clientHeaders['x-grok-session-id'];
  if (clientHeaders['x-grok-conv-id']) return clientHeaders['x-grok-conv-id'];
  if (clientHeaders['x-session-id']) return clientHeaders['x-session-id'];
  if (clientHeaders['x-conversation-id']) return clientHeaders['x-conversation-id'];

  if (jsonBody) {
    if (typeof jsonBody.conversation_id === 'string' && jsonBody.conversation_id) {
      return jsonBody.conversation_id;
    }
    if (typeof jsonBody.session_id === 'string' && jsonBody.session_id) {
      return jsonBody.session_id;
    }
    if (Array.isArray(jsonBody.messages) && jsonBody.messages.length > 0) {
      const firstMsg = JSON.stringify(jsonBody.messages[0]);
      return 'sess_' + crypto.createHash('sha256').update(firstMsg).digest('hex').slice(0, 32);
    }
    if (Array.isArray(jsonBody.input) && jsonBody.input.length > 0) {
      const firstInput = JSON.stringify(jsonBody.input[0]);
      return 'sess_' + crypto.createHash('sha256').update(firstInput).digest('hex').slice(0, 32);
    }
  }

  return 'sess_' + crypto.randomUUID();
}

process.on('uncaughtException', (err) => {
  try {
    fs.appendFileSync('C:\\Users\\USER\\.grok\\proxy-debug.log', `[${new Date().toISOString()}] UncaughtException: ${err.message}\n${err.stack}\n`);
  } catch (e) {}
});

process.on('unhandledRejection', (reason) => {
  try {
    fs.appendFileSync('C:\\Users\\USER\\.grok\\proxy-debug.log', `[${new Date().toISOString()}] UnhandledRejection: ${reason}\n`);
  } catch (e) {}
});

const TARGET_HOST = 'opencode.ai';
const PORT = 5210;

const server = http.createServer((clientReq, clientRes) => {
  let subPath = clientReq.url;
  if (subPath.startsWith('/v1')) {
    subPath = subPath.slice(3);
  }
  const headers = { ...clientReq.headers, host: TARGET_HOST };
  delete headers['connection'];
  delete headers['content-length'];
  delete headers['transfer-encoding'];

  // Enforce active OpenCode API key from environment or config.toml
  let activeKey = process.env.OPENCODE_API_KEY;
  if (!activeKey || !activeKey.startsWith('sk-')) {
    try {
      const configText = fs.readFileSync('C:\\Users\\USER\\.grok\\config.toml', 'utf8');
      const m = configText.match(/api_key\s*=\s*"([^"]+)"/);
      if (m) activeKey = m[1];
    } catch (e) {}
  }
  if (activeKey) {
    headers['authorization'] = `Bearer ${activeKey}`;
  }

  // Merge catalogs for GET /v1/models
  if (clientReq.method === 'GET' && (subPath === '/models' || subPath === '/models/')) {
    headers['x-opencode-session'] = resolveSessionId(clientReq.headers, null);
    if (!headers['user-agent'] || headers['user-agent'].startsWith('curl/')) {
      headers['user-agent'] = 'grok-shell/1.0.13 (windows; x86_64)';
    }

    const fetchCatalog = (path) => new Promise(resolve => {
      const r = https.request({
        hostname: TARGET_HOST,
        port: 443,
        path: path,
        method: 'GET',
        headers: headers
      }, res => {
        let b = '';
        res.on('data', c => b += c);
        res.on('end', () => {
          try { resolve(JSON.parse(b).data || []); } catch(e) { resolve([]); }
        });
      });
      r.on('error', () => resolve([]));
      r.end();
    });

    Promise.all([fetchCatalog('/zen/go/v1/models'), fetchCatalog('/zen/v1/models')]).then(([go, zen]) => {
      const map = new Map();
      for (const m of [...go, ...zen]) {
        if (!map.has(m.id)) map.set(m.id, m);
      }
      const merged = { object: 'list', data: Array.from(map.values()) };
      const body = JSON.stringify(merged);
      clientRes.writeHead(200, {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(body)
      });
      clientRes.end(body);
    }).catch(err => {
      clientRes.writeHead(500, { 'Content-Type': 'application/json' });
      clientRes.end(JSON.stringify({ error: err.message }));
    });
    return;
  }

  // Buffer request body to sanitize multi-turn history and determine upstream route
  const reqChunks = [];
  clientReq.on('data', chunk => reqChunks.push(chunk));
  clientReq.on('end', () => {
    let finalBody = Buffer.concat(reqChunks);
    let targetBase = '/zen/go/v1';
    let parsedJson = null;

    if (finalBody.length > 0) {
      try {
        const json = JSON.parse(finalBody.toString('utf8'));
        parsedJson = json;
        let modified = false;

        // Determine upstream base path: Zen endpoint (/zen/v1) for free models vs Go endpoint (/zen/go/v1)
        if (typeof json.model === 'string' && json.model.endsWith('-free')) {
          targetBase = '/zen/v1';
        } else {
          targetBase = '/zen/go/v1';
        }

        // Normalize reasoning effort based on target endpoint API shape
        const isResponses = subPath.includes('responses');
        if (isResponses) {
          if (json.reasoning_effort) {
            json.reasoning = { effort: json.reasoning_effort };
            delete json.reasoning_effort;
            modified = true;
          } else if (json.reasoning && typeof json.reasoning === 'string') {
            json.reasoning = { effort: json.reasoning };
            modified = true;
          }
        } else {
          // Chat completions expects reasoning_effort as string
          if (json.reasoning && typeof json.reasoning.effort === 'string') {
            json.reasoning_effort = json.reasoning.effort;
            delete json.reasoning;
            modified = true;
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
        }
      } catch (e) {
        // Non-JSON or parse error; forward untouched
      }
    }

    if (finalBody.length > 0) {
      headers['content-length'] = Buffer.byteLength(finalBody);
    }

    // Enforce x-opencode-session header (required by OpenCode Go as of 09/06 for session affinity & caching)
    headers['x-opencode-session'] = resolveSessionId(clientReq.headers, parsedJson);

    // Normalize User-Agent to grok-shell if missing or curl
    if (!headers['user-agent'] || headers['user-agent'].startsWith('curl/')) {
      headers['user-agent'] = 'grok-shell/1.0.13 (windows; x86_64)';
    }

    const targetPath = targetBase + subPath;
    const options = {
      hostname: TARGET_HOST,
      port: 443,
      path: targetPath,
      method: clientReq.method,
      headers: headers
    };

    fs.appendFileSync('C:\\Users\\USER\\.grok\\proxy-debug.log', `[${new Date().toISOString()}] Outgoing Headers: ${JSON.stringify(headers)}\n`);

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

      proxyRes.on('error', (err) => {
        try { clientRes.end(); } catch (e) {}
      });

      proxyRes.on('end', () => {
        if (buffer.trim()) {
          if (!(/^event:\s*ping/m.test(buffer) || /"type":\s*"ping"/m.test(buffer))) {
            try { clientRes.write(buffer + '\n\n'); } catch (e) {}
          }
        }
        try { clientRes.end(); } catch (e) {}
      });
    });

    proxyReq.on('error', (err) => {
      try {
        fs.appendFileSync('C:\\Users\\USER\\.grok\\proxy-debug.log', `[${new Date().toISOString()}] Upstream ProxyReq Error: ${err.message} (${clientReq.method} ${targetPath})\n`);
      } catch (e) {}
      try {
        clientRes.writeHead(502, { 'Content-Type': 'application/json' });
        clientRes.end(JSON.stringify({ error: err.message }));
      } catch (e) {}
    });

    if (finalBody.length > 0) {
      proxyReq.write(finalBody);
    }
    proxyReq.end();
  });
});

server.listen(PORT, '127.0.0.1', () => {
  console.log(`OpenCode Zen Filter Proxy listening on http://127.0.0.1:${PORT}`);
});
