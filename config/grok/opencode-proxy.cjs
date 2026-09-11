// OpenCode Zen Stream Filter, Reasoning Sanitizer & Claude Code Adapter Proxy
//
// Solves:
// 1. Rust Serde SSE enum deserialization in Grok CLI (discards ping frames).
// 2. Cross-turn reasoning history rejection in Grok CLI (sanitizes reasoning output items).
// 3. Claude Code / Anthropic Messages API compatibility:
//    - Translates POST /v1/messages into OpenCode /responses format
//    - Converts OpenCode response stream into Anthropic SSE events in real-time
//    - Handles multi-turn tool_use and tool_result blocks
//    - Supports POST /v1/messages/count_tokens and GET /v1/models
//    - Enforces OpenCode session affinity and official CLI headers

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
  if (clientHeaders['x-claude-session-id']) return clientHeaders['x-claude-session-id'];
  if (clientHeaders['x-claude-code-session-id']) return clientHeaders['x-claude-code-session-id'];

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

// Resolve official OpenCode CLI version and user agent
let opencodeVersion = '1.18.25';
try {
  const pkgPath = 'C:\\Users\\USER\\AppData\\Roaming\\npm\\node_modules\\opencode-ai\\package.json';
  if (fs.existsSync(pkgPath)) {
    const pkg = JSON.parse(fs.readFileSync(pkgPath, 'utf8'));
    if (pkg.version) opencodeVersion = pkg.version;
  }
} catch (e) {}

const OFFICIAL_USER_AGENT = `opencode/${opencodeVersion}`;
const OFFICIAL_CLIENT = 'cli';

function applyOpenCodeHeaders(headers, clientReqHeaders, parsedJson) {
  // Enforce session affinity (required by OpenCode Go as of 09/06)
  headers['x-opencode-session'] = resolveSessionId(clientReqHeaders, parsedJson);
  // Official OpenCode CLI identity headers
  headers['x-opencode-client'] = OFFICIAL_CLIENT;
  headers['user-agent'] = OFFICIAL_USER_AGENT;

  // Request tracking ID
  const reqId = clientReqHeaders['x-opencode-request'] || clientReqHeaders['x-request-id'] || clientReqHeaders['x-grok-req-id'] || crypto.randomUUID();
  headers['x-opencode-request'] = reqId;

  // Strip client telemetry & Anthropic specific headers so upstream gets standard OpenCode CLI headers
  for (const key of Object.keys(headers)) {
    if (
      key.startsWith('x-grok-') ||
      key.startsWith('x-xai-') ||
      key.startsWith('anthropic-') ||
      key === 'x-api-key' ||
      key === 'x-authenticateresponse'
    ) {
      delete headers[key];
    }
  }
}

// Convert Anthropic Messages request into OpenCode Responses API shape
function translateAnthropicRequest(body) {
  let instructions = '';
  if (typeof body.system === 'string') {
    instructions = body.system;
  } else if (Array.isArray(body.system)) {
    instructions = body.system.map(b => (typeof b === 'string' ? b : (b.text || ''))).join('\n');
  }

  const input = [];
  if (Array.isArray(body.messages)) {
    for (const msg of body.messages) {
      if (msg.role === 'user') {
        if (typeof msg.content === 'string') {
          input.push({
            type: 'message',
            role: 'user',
            content: [{ type: 'input_text', text: msg.content }]
          });
        } else if (Array.isArray(msg.content)) {
          const contentParts = [];
          for (const block of msg.content) {
            if (block.type === 'tool_result') {
              let outStr = '';
              if (typeof block.content === 'string') {
                outStr = block.content;
              } else if (Array.isArray(block.content)) {
                outStr = block.content.map(c => (typeof c === 'string' ? c : (c.text || JSON.stringify(c)))).join('\n');
              } else if (block.content) {
                outStr = JSON.stringify(block.content);
              }
              if (block.is_error) outStr = `[Error] ${outStr}`;
              input.push({
                type: 'function_call_output',
                call_id: block.tool_use_id,
                output: outStr
              });
            } else if (block.type === 'text') {
              contentParts.push({ type: 'input_text', text: block.text || '' });
            } else if (block.type === 'image' && block.source) {
              contentParts.push({
                type: 'input_image',
                image_url: `data:${block.source.media_type};base64,${block.source.data}`
              });
            }
          }
          if (contentParts.length > 0) {
            input.push({
              type: 'message',
              role: 'user',
              content: contentParts
            });
          }
        }
      } else if (msg.role === 'assistant') {
        if (typeof msg.content === 'string') {
          input.push({
            type: 'message',
            role: 'assistant',
            content: [{ type: 'output_text', text: msg.content }]
          });
        } else if (Array.isArray(msg.content)) {
          const textParts = [];
          for (const block of msg.content) {
            if (block.type === 'text') {
              textParts.push({ type: 'output_text', text: block.text || '' });
            } else if (block.type === 'tool_use') {
              input.push({
                type: 'function_call',
                id: block.id,
                call_id: block.id,
                name: block.name,
                arguments: typeof block.input === 'string' ? block.input : JSON.stringify(block.input || {})
              });
            }
          }
          if (textParts.length > 0) {
            input.push({
              type: 'message',
              role: 'assistant',
              content: textParts
            });
          }
        }
      }
    }
  }

  const tools = [];
  if (Array.isArray(body.tools)) {
    for (const t of body.tools) {
      tools.push({
        type: 'function',
        name: t.name,
        description: t.description || '',
        parameters: t.input_schema || { type: 'object', properties: {} }
      });
    }
  }

  let clientModel = body.model || 'muse-spark-1.3-contributor';
  let model = clientModel;
  let targetBase = '/zen/go/v1';

  if (model === 'muse-spark-1.3-free' || model.includes('contributor-free') || model.endsWith('-free')) {
    model = 'muse-spark-1.3-contributor-free';
    targetBase = '/zen/v1';
  } else if (model.includes('muse-spark')) {
    model = 'muse-spark-1.3-contributor';
    targetBase = '/zen/go/v1';
  } else if (['claude-sonnet-5', 'claude-sonnet-4-6', 'claude-sonnet-4-5', 'claude-opus-5', 'claude-haiku-4-5'].includes(model)) {
    targetBase = '/zen/go/v1';
  } else {
    // Default any generic Claude alias to muse-spark-1.3-contributor
    model = 'muse-spark-1.3-contributor';
    targetBase = '/zen/go/v1';
  }

  const converted = {
    model: model,
    stream: true,
    input: input
  };
  if (instructions) converted.instructions = instructions;
  if (tools.length > 0) converted.tools = tools;

  return {
    converted,
    targetBase,
    clientModel,
    isStream: body.stream !== false
  };
}

const server = http.createServer((clientReq, clientRes) => {
  let subPath = clientReq.url;
  if (subPath.startsWith('/v1')) {
    subPath = subPath.slice(3);
  }
  const qIdx = subPath.indexOf('?');
  const cleanPath = qIdx !== -1 ? subPath.slice(0, qIdx) : subPath;

  const headers = { ...clientReq.headers, host: TARGET_HOST };
  delete headers['connection'];
  delete headers['content-length'];
  delete headers['transfer-encoding'];

  // Enforce active OpenCode API key from config.toml (prioritized for live reloading) or environment
  let activeKey = null;
  try {
    const configText = fs.readFileSync('C:\\Users\\USER\\.grok\\config.toml', 'utf8');
    const m = configText.match(/api_key\s*=\s*"([^"]+)"/);
    if (m && m[1].startsWith('sk-')) activeKey = m[1];
  } catch (e) {}
  if (!activeKey) {
    activeKey = process.env.OPENCODE_API_KEY;
  }
  if (activeKey) {
    headers['authorization'] = `Bearer ${activeKey}`;
  }

  clientReq.on('error', (err) => {
    try {
      fs.appendFileSync('C:\\Users\\USER\\.grok\\proxy-debug.log', `[${new Date().toISOString()}] ClientReq Error: ${err.message}\n`);
    } catch (e) {}
  });

  clientRes.on('error', (err) => {
    try {
      fs.appendFileSync('C:\\Users\\USER\\.grok\\proxy-debug.log', `[${new Date().toISOString()}] ClientRes Error: ${err.message}\n`);
    } catch (e) {}
  });

  // Handle Anthropic token counting (POST /v1/messages/count_tokens)
  if (clientReq.method === 'POST' && (cleanPath === '/messages/count_tokens' || cleanPath === '/messages/count_tokens/')) {
    const reqChunks = [];
    clientReq.on('data', c => reqChunks.push(c));
    clientReq.on('end', () => {
      try {
        const raw = Buffer.concat(reqChunks).toString('utf8');
        const est = Math.max(1, Math.ceil(raw.length / 3.5));
        const resBody = JSON.stringify({ input_tokens: est });
        clientRes.writeHead(200, {
          'Content-Type': 'application/json',
          'Content-Length': Buffer.byteLength(resBody)
        });
        clientRes.end(resBody);
      } catch (e) {
        clientRes.writeHead(400, { 'Content-Type': 'application/json' });
        clientRes.end(JSON.stringify({ error: e.message }));
      }
    });
    return;
  }

  // Merge catalogs for GET /v1/models (also used by Claude Code gateway model discovery)
  if (clientReq.method === 'GET' && (cleanPath === '/models' || cleanPath === '/models/')) {
    applyOpenCodeHeaders(headers, clientReq.headers, null);

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

  // Handle Anthropic Messages API (POST /v1/messages) for Claude Code
  if (clientReq.method === 'POST' && (cleanPath === '/messages' || cleanPath === '/messages/')) {
    const reqChunks = [];
    clientReq.on('data', chunk => reqChunks.push(chunk));
    clientReq.on('end', () => {
      let body;
      try {
        body = JSON.parse(Buffer.concat(reqChunks).toString('utf8'));
      } catch (e) {
        clientRes.writeHead(400, { 'Content-Type': 'application/json' });
        return clientRes.end(JSON.stringify({ type: 'error', error: { type: 'invalid_request_error', message: e.message } }));
      }

      const { converted, targetBase, clientModel, isStream } = translateAnthropicRequest(body);
      const outgoingBody = Buffer.from(JSON.stringify(converted));

      headers['content-type'] = 'application/json';
      headers['content-length'] = Buffer.byteLength(outgoingBody);
      headers['accept'] = 'text/event-stream';

      applyOpenCodeHeaders(headers, clientReq.headers, converted);

      const targetPath = `${targetBase}/responses`;
      const options = {
        hostname: TARGET_HOST,
        port: 443,
        path: targetPath,
        method: 'POST',
        headers: headers
      };

      const logHeaders = { ...headers };
      if (logHeaders.authorization) logHeaders.authorization = logHeaders.authorization.slice(0, 15) + '...';
      fs.appendFileSync('C:\\Users\\USER\\.grok\\proxy-debug.log', `[${new Date().toISOString()}] [Anthropic->OpenCode] Model: ${clientModel} -> ${converted.model} (${targetPath})\n`);

      const proxyReq = https.request(options, (proxyRes) => {
        if (proxyRes.statusCode >= 400) {
          let errChunks = [];
          proxyRes.on('data', c => errChunks.push(c));
          proxyRes.on('end', () => {
            const errBody = Buffer.concat(errChunks).toString('utf8');
            try {
              fs.appendFileSync('C:\\Users\\USER\\.grok\\proxy-debug.log', `[${new Date().toISOString()}] Upstream Error [${proxyRes.statusCode}]: ${errBody.slice(0, 500)}\n`);
            } catch (e) {}
            clientRes.writeHead(proxyRes.statusCode, { 'Content-Type': 'application/json' });
            clientRes.end(JSON.stringify({
              type: 'error',
              error: {
                type: proxyRes.statusCode === 429 ? 'rate_limit_error' : 'api_error',
                message: errBody || 'Upstream OpenCode error'
              }
            }));
          });
          return;
        }

        if (isStream) {
          clientRes.writeHead(200, {
            'Content-Type': 'text/event-stream',
            'Cache-Control': 'no-cache',
            'Connection': 'keep-alive'
          });

          let buffer = '';
          let msgId = 'msg_' + crypto.randomUUID().replace(/-/g, '').slice(0, 24);
          let currentBlockIndex = -1;
          let textBlockIndex = -1;
          let toolBlockIndex = -1;
          let hasToolCall = false;
          let inTokens = 0;
          let outTokens = 1;
          let messageStarted = false;

          proxyRes.on('data', (chunk) => {
            buffer += chunk.toString('utf8');
            const parts = buffer.split('\n\n');
            buffer = parts.pop();

            for (const part of parts) {
              if (!part.trim()) continue;
              const lines = part.split('\n');
              const eventLine = lines.find(l => l.startsWith('event:'));
              const dataLine = lines.find(l => l.startsWith('data:'));
              if (!eventLine || !dataLine) continue;

              const event = eventLine.replace('event:', '').trim();
              if (event === 'ping') continue;

              let data;
              try {
                data = JSON.parse(dataLine.replace('data:', '').trim());
              } catch (e) {
                continue;
              }

              if (event === 'response.created') {
                if (data.response && data.response.id) {
                  msgId = 'msg_' + data.response.id.replace('resp_', '');
                }
                if (data.response && data.response.usage) {
                  inTokens = data.response.usage.input_tokens || 0;
                }
                if (!messageStarted) {
                  messageStarted = true;
                  clientRes.write(`event: message_start\ndata: ${JSON.stringify({
                    type: 'message_start',
                    message: {
                      id: msgId,
                      type: 'message',
                      role: 'assistant',
                      content: [],
                      model: clientModel,
                      stop_reason: null,
                      stop_sequence: null,
                      usage: { input_tokens: inTokens, output_tokens: 1 }
                    }
                  })}\n\n`);
                }
              } else if (event === 'response.output_item.added') {
                if (data.item && data.item.type === 'message') {
                  currentBlockIndex++;
                  textBlockIndex = currentBlockIndex;
                  clientRes.write(`event: content_block_start\ndata: ${JSON.stringify({
                    type: 'content_block_start',
                    index: textBlockIndex,
                    content_block: { type: 'text', text: '' }
                  })}\n\n`);
                } else if (data.item && data.item.type === 'function_call') {
                  currentBlockIndex++;
                  toolBlockIndex = currentBlockIndex;
                  hasToolCall = true;
                  clientRes.write(`event: content_block_start\ndata: ${JSON.stringify({
                    type: 'content_block_start',
                    index: toolBlockIndex,
                    content_block: {
                      type: 'tool_use',
                      id: data.item.call_id || data.item.id,
                      name: data.item.name,
                      input: {}
                    }
                  })}\n\n`);
                }
              } else if (event === 'response.output_text.delta') {
                if (textBlockIndex >= 0 && data.delta) {
                  clientRes.write(`event: content_block_delta\ndata: ${JSON.stringify({
                    type: 'content_block_delta',
                    index: textBlockIndex,
                    delta: { type: 'text_delta', text: data.delta }
                  })}\n\n`);
                }
              } else if (event === 'response.function_call_arguments.delta') {
                if (toolBlockIndex >= 0 && data.delta) {
                  clientRes.write(`event: content_block_delta\ndata: ${JSON.stringify({
                    type: 'content_block_delta',
                    index: toolBlockIndex,
                    delta: { type: 'input_json_delta', partial_json: data.delta }
                  })}\n\n`);
                }
              } else if (event === 'response.output_item.done') {
                if (data.item && data.item.type === 'message' && textBlockIndex >= 0) {
                  clientRes.write(`event: content_block_stop\ndata: ${JSON.stringify({
                    type: 'content_block_stop',
                    index: textBlockIndex
                  })}\n\n`);
                  textBlockIndex = -1;
                } else if (data.item && data.item.type === 'function_call' && toolBlockIndex >= 0) {
                  clientRes.write(`event: content_block_stop\ndata: ${JSON.stringify({
                    type: 'content_block_stop',
                    index: toolBlockIndex
                  })}\n\n`);
                  toolBlockIndex = -1;
                }
              } else if (event === 'response.completed') {
                if (data.response && data.response.usage) {
                  outTokens = data.response.usage.output_tokens || 1;
                }
                const stopReason = hasToolCall ? 'tool_use' : 'end_turn';
                clientRes.write(`event: message_delta\ndata: ${JSON.stringify({
                  type: 'message_delta',
                  delta: { stop_reason: stopReason, stop_sequence: null },
                  usage: { output_tokens: outTokens }
                })}\n\n`);
                clientRes.write(`event: message_stop\ndata: ${JSON.stringify({
                  type: 'message_stop'
                })}\n\n`);
              }
            }
          });

          proxyRes.on('error', () => {
            try { clientRes.end(); } catch (e) {}
          });

          proxyRes.on('end', () => {
            try { clientRes.end(); } catch (e) {}
          });
        } else {
          // Non-streaming response buffer
          let buffer = '';
          let msgId = 'msg_' + crypto.randomUUID().replace(/-/g, '').slice(0, 24);
          let accumulatedText = '';
          const toolsCalled = [];
          let currentTool = null;
          let inTokens = 0;
          let outTokens = 1;

          proxyRes.on('data', chunk => {
            buffer += chunk.toString('utf8');
            const parts = buffer.split('\n\n');
            buffer = parts.pop();

            for (const part of parts) {
              if (!part.trim()) continue;
              const lines = part.split('\n');
              const eventLine = lines.find(l => l.startsWith('event:'));
              const dataLine = lines.find(l => l.startsWith('data:'));
              if (!eventLine || !dataLine) continue;

              const event = eventLine.replace('event:', '').trim();
              if (event === 'ping') continue;

              let data;
              try { data = JSON.parse(dataLine.replace('data:', '').trim()); } catch (e) { continue; }

              if (event === 'response.created') {
                if (data.response && data.response.id) msgId = 'msg_' + data.response.id.replace('resp_', '');
                if (data.response && data.response.usage) inTokens = data.response.usage.input_tokens || 0;
              } else if (event === 'response.output_item.added') {
                if (data.item && data.item.type === 'function_call') {
                  currentTool = {
                    id: data.item.call_id || data.item.id,
                    name: data.item.name,
                    arguments: ''
                  };
                  toolsCalled.push(currentTool);
                }
              } else if (event === 'response.output_text.delta') {
                if (data.delta) accumulatedText += data.delta;
              } else if (event === 'response.function_call_arguments.delta') {
                if (currentTool && data.delta) currentTool.arguments += data.delta;
              } else if (event === 'response.completed') {
                if (data.response && data.response.usage) outTokens = data.response.usage.output_tokens || 1;
              }
            }
          });

          proxyRes.on('end', () => {
            const contentBlocks = [];
            if (accumulatedText) contentBlocks.push({ type: 'text', text: accumulatedText });
            for (const t of toolsCalled) {
              let parsedInput = {};
              try { parsedInput = JSON.parse(t.arguments || '{}'); } catch (e) {}
              contentBlocks.push({
                type: 'tool_use',
                id: t.id,
                name: t.name,
                input: parsedInput
              });
            }
            const resObj = {
              id: msgId,
              type: 'message',
              role: 'assistant',
              content: contentBlocks,
              model: clientModel,
              stop_reason: toolsCalled.length > 0 ? 'tool_use' : 'end_turn',
              stop_sequence: null,
              usage: { input_tokens: inTokens, output_tokens: outTokens }
            };
            const jsonStr = JSON.stringify(resObj);
            clientRes.writeHead(200, {
              'Content-Type': 'application/json',
              'Content-Length': Buffer.byteLength(jsonStr)
            });
            clientRes.end(jsonStr);
          });
        }
      });

      proxyReq.on('error', (err) => {
        try {
          fs.appendFileSync('C:\\Users\\USER\\.grok\\proxy-debug.log', `[${new Date().toISOString()}] Anthropic ProxyReq Error: ${err.message}\n`);
        } catch (e) {}
        try {
          clientRes.writeHead(502, { 'Content-Type': 'application/json' });
          clientRes.end(JSON.stringify({ type: 'error', error: { type: 'api_error', message: err.message } }));
        } catch (e) {}
      });

      clientRes.on('close', () => {
        if (!clientRes.writableEnded) {
          proxyReq.destroy();
        }
      });

      proxyReq.write(outgoingBody);
      proxyReq.end();
    });
    return;
  }

  // Standard OpenAI Responses / Chat Completions handler (used by Grok CLI)
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

    // Apply official OpenCode identity and session headers, stripping Grok client metadata
    applyOpenCodeHeaders(headers, clientReq.headers, parsedJson);

    const targetPath = targetBase + subPath;
    const options = {
      hostname: TARGET_HOST,
      port: 443,
      path: targetPath,
      method: clientReq.method,
      headers: headers
    };

    const logHeaders = { ...headers };
    if (logHeaders.authorization) {
      logHeaders.authorization = logHeaders.authorization.slice(0, 15) + '...';
    }
    fs.appendFileSync('C:\\Users\\USER\\.grok\\proxy-debug.log', `[${new Date().toISOString()}] Outgoing Headers: ${JSON.stringify(logHeaders)}\n`);

    const proxyReq = https.request(options, (proxyRes) => {
      const contentType = proxyRes.headers['content-type'] || '';
      const isSSE = contentType.includes('text/event-stream');

      if (!isSSE) {
        let errChunks = [];
        proxyRes.on('data', c => errChunks.push(c));
        proxyRes.on('end', () => {
          if (proxyRes.statusCode >= 400) {
            const errBody = Buffer.concat(errChunks).toString('utf8');
            try {
              fs.appendFileSync('C:\\Users\\USER\\.grok\\proxy-debug.log', `[${new Date().toISOString()}] Upstream Error [${proxyRes.statusCode}]: ${errBody.slice(0, 500)}\n`);
            } catch (e) {}
          }
        });
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

server.on('clientError', (err, socket) => {
  try {
    fs.appendFileSync('C:\\Users\\USER\\.grok\\proxy-debug.log', `[${new Date().toISOString()}] Server ClientError: ${err.message}\n`);
  } catch (e) {}
  if (err.code === 'ECONNRESET' || !socket.writable) {
    return;
  }
  socket.end('HTTP/1.1 400 Bad Request\r\n\r\n');
});

server.listen(PORT, '127.0.0.1', () => {
  console.log(`OpenCode Zen Filter Proxy listening on http://127.0.0.1:${PORT}`);
});
