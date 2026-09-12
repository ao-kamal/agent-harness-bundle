
function cleanParameters(schema) {
  if (!schema || typeof schema !== 'object') return { type: 'object', properties: {} };
  const cleaned = Array.isArray(schema) ? [] : {};
  for (const [k, v] of Object.entries(schema)) {
    if (k === '$schema') continue;
    cleaned[k] = typeof v === 'object' && v !== null ? cleanParameters(v) : v;
  }
  if (!Array.isArray(cleaned)) {
    if (!cleaned.type) cleaned.type = 'object';
    if (cleaned.type === 'object' && !cleaned.properties) cleaned.properties = {};
  }
  return cleaned;
}
const http = require('http');
const https = require('https');
const fs = require('fs');
const crypto = require('crypto');

process.on('uncaughtException', (err) => {
  try {
    fs.appendFileSync('C:\\Users\\USER\\.grok\\proxy-debug.log', `[${new Date().toISOString()}] UncaughtException: ${err.stack || err.message}\n`);
  } catch (e) {}
});

process.on('unhandledRejection', (reason) => {
  try {
    fs.appendFileSync('C:\\Users\\USER\\.grok\\proxy-debug.log', `[${new Date().toISOString()}] UnhandledRejection: ${reason}\n`);
  } catch (e) {}
});

const PORT = 5210;
const TARGET_HOST = 'opencode.ai';

const GO_MODELS_LIST = [
  "minimax-m3", "minimax-m2.7", "minimax-m2.5", "kimi-k3", "kimi-k2.7-code", "kimi-k2.6", "longcat-2.0", "kimi-k2.5",
  "glm-5.2", "glm-5.3-flash", "glm-5.3", "glm-5.1", "glm-5", "deepseek-v4-pro", "deepseek-v4-flash", "deepseek-flash",
  "deepseek-v4.1-flash", "deepseek-v4-flash-vision-exp", "qwen3.7-max", "qwen3.8-max", "qwen3.8-flash", "qwen3.7-plus",
  "qwen3.6-plus", "qwen3.5-plus", "mimo-v2-pro", "mimo-v2-omni", "mimo-v2.5-pro", "mimo-v2.5", "hy4-preview", "hy3",
  "hy3-preview", "gpt-5.6-luna", "grok-4.5", "grok-4.6", "muse-spark-1.3-contributor", "muse-spark-1.2-contributor", "omen-alpha"
];
const GO_MODELS_SET = new Set(GO_MODELS_LIST);

const RESPONSES_MODELS_SET = new Set([
  'muse-spark-1.3-contributor', 'muse-spark-1.2-contributor', 'muse-spark-1.3-contributor-free', 'muse-spark-1.2-contributor-free',
  'muse-spark-1.3', 'muse-spark-1.2',
  'deepseek-v4.1-flash', 'deepseek-v4-pro', 'deepseek-v4-flash', 'deepseek-flash',
  'grok-4.6', 'gpt-5.6-luna',
  'claude-fable-5', 'claude-fable-5-1', 'claude-opus-5', 'claude-opus-4-8', 'claude-opus-4-7', 'claude-opus-4-6', 'claude-opus-4-5',
  'claude-sonnet-5', 'claude-sonnet-4-6', 'claude-sonnet-4-5', 'claude-sonnet-4', 'claude-haiku-4-5'
]);

function routeAnthropicModel(clientModel) {
  let model = clientModel || 'muse-spark-1.3-contributor';
  if (model.startsWith('anthropic/')) model = model.slice(10);
  if (model.startsWith('claude-')) {
    if (/^claude-(opus|sonnet|haiku|fable)/i.test(model)) {
      // Native OpenCode Claude model
    } else if (model.includes('muse-spark-1.3-free') || model.includes('contributor-free')) {
      model = 'muse-spark-1.3-contributor-free';
    } else if (model.includes('muse-spark')) {
      model = 'muse-spark-1.3-contributor';
    } else {
      model = model.slice(7);
    }
  }

  let targetBase = '/zen/go/v1';
  if (model.endsWith('-free') || model.includes('contributor-free') || !GO_MODELS_SET.has(model)) {
    targetBase = '/zen/v1';
  } else {
    targetBase = '/zen/go/v1';
  }

  const endpointType = RESPONSES_MODELS_SET.has(model) ? 'responses' : 'chat';
  return { model, targetBase, endpointType };
}

function applyOpenCodeHeaders(headers, clientReqHeaders, convertedPayload) {
  headers['user-agent'] = 'opencode/1.18.25';
  headers['x-opencode-client'] = 'cli';
  headers['x-opencode-session'] = 'opencode-cli-session';
  headers['x-opencode-request'] = crypto.randomUUID();

  if (convertedPayload && convertedPayload.model) {
    headers['x-opencode-model'] = convertedPayload.model;
  }
  if (clientReqHeaders && clientReqHeaders['x-opencode-directory']) {
    headers['x-opencode-directory'] = clientReqHeaders['x-opencode-directory'];
  }
}

function sanitizeParameters(rawParams) {
  if (!rawParams || typeof rawParams !== 'object') {
    return { type: 'object', properties: {} };
  }
  const params = JSON.parse(JSON.stringify(rawParams));
  delete params['$schema'];
  delete params['$id'];
  if (!params.type) params.type = 'object';
  if (!params.properties) params.properties = {};
  return params;
}

function translateAnthropicToResponses(body, model) {
  const input = [];
  let instructions = '';

  if (body.system) {
    if (typeof body.system === 'string') {
      instructions = body.system;
    } else if (Array.isArray(body.system)) {
      instructions = body.system.map(s => (typeof s === 'string' ? s : s.text || '')).join('\n');
    }
  }

  if (Array.isArray(body.messages)) {
    for (const msg of body.messages) {
      const textType = msg.role === 'assistant' ? 'output_text' : 'input_text';

      if (typeof msg.content === 'string') {
        const text = msg.content || ' ';
        input.push({
          type: 'message',
          role: msg.role,
          content: [{ type: textType, text: text }]
        });
      } else if (Array.isArray(msg.content)) {
        let textBlocks = [];
        let hasToolBlock = false;

        for (const block of msg.content) {
          if (!block || typeof block !== 'object') continue;

          // Skip Anthropic-specific internal thinking blocks
          if (block.type === 'thinking' || block.type === 'redacted_thinking') {
            continue;
          }

          if (block.type === 'text') {
            if (block.text) {
              textBlocks.push({ type: textType, text: block.text });
            }
          } else if (block.type === 'tool_use') {
            hasToolBlock = true;
            if (textBlocks.length > 0) {
              input.push({
                type: 'message',
                role: msg.role,
                content: textBlocks
              });
              textBlocks = [];
            }
            let argsStr = '{}';
            if (typeof block.input === 'string') {
              argsStr = block.input;
            } else if (block.input) {
              try {
                argsStr = JSON.stringify(block.input);
              } catch (e) {
                argsStr = '{}';
              }
            }
            input.push({
              type: 'function_call',
              id: block.id,
              call_id: block.id,
              name: block.name,
              arguments: argsStr
            });
          } else if (block.type === 'tool_result') {
            hasToolBlock = true;
            if (textBlocks.length > 0) {
              input.push({
                type: 'message',
                role: msg.role,
                content: textBlocks
              });
              textBlocks = [];
            }
            let resText = '';
            if (typeof block.content === 'string') {
              resText = block.content;
            } else if (Array.isArray(block.content)) {
              resText = block.content.map(c => (typeof c === 'string' ? c : c.text || JSON.stringify(c))).join('\n');
            }
            input.push({
              type: 'function_call_output',
              call_id: block.tool_use_id,
              output: resText || 'ok'
            });
          }
        }

        if (textBlocks.length > 0) {
          input.push({
            type: 'message',
            role: msg.role,
            content: textBlocks
          });
        } else if (!hasToolBlock) {
          // If no text and no tool blocks were processed, provide a safe fallback so the message isn't dropped
          input.push({
            type: 'message',
            role: msg.role,
            content: [{ type: textType, text: ' ' }]
          });
        }
      }
    }
  }

  const tools = [];
  if (Array.isArray(body.tools)) {
    for (const t of body.tools) {
      if (!t || !t.name) continue;
      tools.push({
        type: 'function',
        name: t.name,
        description: t.description || '',
        parameters: sanitizeParameters(t.input_schema)
      });
    }
  }

  const converted = {
    model: model,
    stream: true,
    input: input
  };
  if (instructions) converted.instructions = instructions;
  if (tools.length > 0) converted.tools = tools;

  return converted;
}

function translateAnthropicToChat(body, model) {
  const messages = [];

  if (body.system) {
    let sysText = typeof body.system === 'string' ? body.system : (body.system.map(s => s.text || '').join('\n'));
    if (sysText) messages.push({ role: 'system', content: sysText });
  }

  if (Array.isArray(body.messages)) {
    for (const msg of body.messages) {
      if (typeof msg.content === 'string') {
        messages.push({ role: msg.role, content: msg.content });
      } else if (Array.isArray(msg.content)) {
        let textParts = [];
        let toolCalls = [];
        let toolResults = [];

        for (const block of msg.content) {
          if (block.type === 'text') {
            textParts.push(block.text);
          } else if (block.type === 'tool_use') {
            toolCalls.push({
              id: block.id,
              type: 'function',
              function: {
                name: block.name,
                arguments: typeof block.input === 'string' ? block.input : JSON.stringify(block.input || {})
              }
            });
          } else if (block.type === 'tool_result') {
            let resText = typeof block.content === 'string' ? block.content : JSON.stringify(block.content);
            toolResults.push({
              role: 'tool',
              tool_call_id: block.tool_use_id,
              content: resText || 'ok'
            });
          }
        }

        if (toolResults.length > 0) {
          for (const tr of toolResults) messages.push(tr);
        } else {
          const chatMsg = { role: msg.role };
          if (textParts.length > 0 || toolCalls.length === 0) chatMsg.content = textParts.join('\n');
          if (toolCalls.length > 0) chatMsg.tool_calls = toolCalls;
          messages.push(chatMsg);
        }
      }
    }
  }

  const payload = { model, messages, stream: true };
  if (body.max_tokens) payload.max_tokens = body.max_tokens;
  if (body.temperature !== undefined) payload.temperature = body.temperature;

  if (Array.isArray(body.tools) && body.tools.length > 0) {
    payload.tools = body.tools.map(t => ({
      type: 'function',
      function: {
        name: t.name,
        description: t.description || '',
        parameters: sanitizeParameters(t.input_schema)
      }
    }));
  }

  return payload;
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
  delete headers['accept-encoding'];
  delete headers['anthropic-version'];
  delete headers['anthropic-beta'];
  delete headers['anthropic-dangerous-direct-browser-access'];
  delete headers['x-api-key'];
  headers['accept-encoding'] = 'identity';

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

  // Token count mock endpoint (POST /v1/messages/count_tokens)
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

  // Model catalog endpoint (GET /v1/models) - dynamically exposes ALL OpenCode models
  if (clientReq.method === 'GET' && (cleanPath === '/models' || cleanPath === '/models/')) {
    const fetchCatalog = (p) => new Promise((resolve) => {
      const r = https.request({
        hostname: TARGET_HOST,
        port: 443,
        path: p,
        method: 'GET',
        headers: {
          ...headers,
          'user-agent': 'opencode/1.18.25',
          'x-opencode-client': 'cli'
        }
      }, (res) => {
        let d = '';
        res.on('data', c => d += c);
        res.on('end', () => {
          try {
            resolve(JSON.parse(d).data || []);
          } catch (e) {
            resolve([]);
          }
        });
      });
      r.on('error', () => resolve([]));
      r.end();
    });

    Promise.all([fetchCatalog('/zen/go/v1/models'), fetchCatalog('/zen/v1/models')]).then(([go, zen]) => {
      const map = new Map();
      const goIds = new Set(go.map(m => m.id));

      for (const m of [...go, ...zen]) {
        if (!map.has(m.id)) {
          const item = { ...m };
          const tier = goIds.has(m.id) ? 'OpenCode Go' : 'OpenCode Zen';
          if (!item.display_name) item.display_name = `${item.id} (${tier})`;
          map.set(item.id, item);

          // Add claude- prefixed alias so Claude Code discovery filter /(claude|anthropic)/i matches it!
          if (!/(claude|anthropic)/i.test(m.id)) {
            const aliasId = `claude-${m.id}`;
            map.set(aliasId, {
              id: aliasId,
              object: 'model',
              display_name: `${m.id} (${tier})`,
              description: `OpenCode ${tier} model ${m.id}`
            });
          }
        }
      }

      // Add alias for free Muse Spark
      map.set('claude-muse-spark-1.3-free', {
        id: 'claude-muse-spark-1.3-free',
        object: 'model',
        display_name: 'muse-spark-1.3-free (OpenCode Zen)',
        description: 'OpenCode Zen 100% free model'
      });

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

  // Anthropic Messages API (POST /v1/messages) for Claude Code
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

      const clientModel = body.model || 'muse-spark-1.3-contributor';
      const { model, targetBase, endpointType } = routeAnthropicModel(clientModel);
      const isStream = body.stream !== false;

      let outgoingPayload;
      let targetPath;

      if (endpointType === 'responses') {
        outgoingPayload = translateAnthropicToResponses(body, model);
        targetPath = `${targetBase}/responses`;
      } else {
        outgoingPayload = translateAnthropicToChat(body, model);
        targetPath = `${targetBase}/chat/completions`;
      }

      const outgoingBody = Buffer.from(JSON.stringify(outgoingPayload));

      headers['content-type'] = 'application/json';
      headers['content-length'] = Buffer.byteLength(outgoingBody);
      headers['accept'] = 'text/event-stream';

      applyOpenCodeHeaders(headers, clientReq.headers, outgoingPayload);

      const options = {
        hostname: TARGET_HOST,
        port: 443,
        path: targetPath,
        method: 'POST',
        headers: headers
      };

      fs.appendFileSync('C:\\Users\\USER\\.grok\\proxy-debug.log', `[${new Date().toISOString()}] [Anthropic->OpenCode] Model: ${clientModel} -> ${model} (${targetPath}) [${endpointType}]\n`);

      const proxyReq = https.request(options, (proxyRes) => {
        if (proxyRes.statusCode >= 400) {
          let errChunks = [];
          proxyRes.on('data', c => errChunks.push(c));
          proxyRes.on('end', () => {
            const errBody = Buffer.concat(errChunks).toString('utf8');
            try {
              fs.appendFileSync('C:\\Users\\USER\\.grok\\proxy-debug.log', `[${new Date().toISOString()}] Upstream Error [${proxyRes.statusCode}]: ${errBody.slice(0, 500)}\n`);
              fs.writeFileSync('C:\\Users\\USER\\.grok\\debug-last-failed-request.json', JSON.stringify({
                timestamp: new Date().toISOString(),
                statusCode: proxyRes.statusCode,
                targetPath,
                clientModel,
                routedModel: model,
                errorBody: errBody,
                outgoingPayload
              }, null, 2));
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

        if (endpointType === 'chat') {
          // Streaming chat completions to Anthropic SSE
          if (isStream) {
            clientRes.writeHead(200, {
              'Content-Type': 'text/event-stream',
              'Cache-Control': 'no-cache',
              'Connection': 'keep-alive'
            });

            let buffer = '';
            let msgId = 'msg_' + crypto.randomUUID().replace(/-/g, '').slice(0, 24);
            let firstChunk = true;
            let blockIndex = 0;
            let textBlockIndex = -1;
            let toolBlockIndex = -1;
            let hasToolCall = false;
            let inTokens = 0;
            let outTokens = 1;

            proxyRes.on('data', chunk => {
              buffer += chunk.toString('utf8');
              const parts = buffer.split('\n\n');
              buffer = parts.pop();

              for (const part of parts) {
                if (!part.trim()) continue;
                const lines = part.split('\n');
                for (const line of lines) {
                  if (!line.startsWith('data:')) continue;
                  const raw = line.slice(5).trim();
                  if (!raw) continue;
                  if (raw === '[DONE]') {
                    if (textBlockIndex >= 0) {
                      clientRes.write(`event: content_block_stop\ndata: ${JSON.stringify({ type: 'content_block_stop', index: textBlockIndex })}\n\n`);
                      textBlockIndex = -1;
                    }
                    if (toolBlockIndex >= 0) {
                      clientRes.write(`event: content_block_stop\ndata: ${JSON.stringify({ type: 'content_block_stop', index: toolBlockIndex })}\n\n`);
                      toolBlockIndex = -1;
                    }
                    const stopReason = hasToolCall ? 'tool_use' : 'end_turn';
                    clientRes.write(`event: message_delta\ndata: ${JSON.stringify({
                      type: 'message_delta',
                      delta: { stop_reason: stopReason, stop_sequence: null },
                      usage: { output_tokens: outTokens }
                    })}\n\n`);
                    clientRes.write(`event: message_stop\ndata: ${JSON.stringify({ type: 'message_stop' })}\n\n`);
                    return;
                  }

                  let data;
                  try { data = JSON.parse(raw); } catch (e) { continue; }

                  if (firstChunk) {
                    firstChunk = false;
                    if (data.id) msgId = 'msg_' + data.id.replace('chatcmpl-', '');
                    if (data.usage && data.usage.prompt_tokens) inTokens = data.usage.prompt_tokens;
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

                  if (data.usage && data.usage.completion_tokens) {
                    outTokens = data.usage.completion_tokens;
                  }

                  const choice = data.choices && data.choices[0];
                  if (!choice) continue;

                  const delta = choice.delta;
                  if (delta) {
                    if (delta.content) {
                      if (textBlockIndex < 0) {
                        textBlockIndex = blockIndex++;
                        clientRes.write(`event: content_block_start\ndata: ${JSON.stringify({
                          type: 'content_block_start',
                          index: textBlockIndex,
                          content_block: { type: 'text', text: '' }
                        })}\n\n`);
                      }
                      clientRes.write(`event: content_block_delta\ndata: ${JSON.stringify({
                        type: 'content_block_delta',
                        index: textBlockIndex,
                        delta: { type: 'text_delta', text: delta.content }
                      })}\n\n`);
                    }

                    if (Array.isArray(delta.tool_calls)) {
                      for (const tc of delta.tool_calls) {
                        if (tc.function && tc.function.name) {
                          if (textBlockIndex >= 0) {
                            clientRes.write(`event: content_block_stop\ndata: ${JSON.stringify({ type: 'content_block_stop', index: textBlockIndex })}\n\n`);
                            textBlockIndex = -1;
                          }
                          hasToolCall = true;
                          toolBlockIndex = blockIndex++;
                          clientRes.write(`event: content_block_start\ndata: ${JSON.stringify({
                            type: 'content_block_start',
                            index: toolBlockIndex,
                            content_block: {
                              type: 'tool_use',
                              id: tc.id || 'call_' + crypto.randomUUID().slice(0, 8),
                              name: tc.function.name,
                              input: {}
                            }
                          })}\n\n`);
                        }
                        if (tc.function && tc.function.arguments && toolBlockIndex >= 0) {
                          clientRes.write(`event: content_block_delta\ndata: ${JSON.stringify({
                            type: 'content_block_delta',
                            index: toolBlockIndex,
                            delta: { type: 'input_json_delta', partial_json: tc.function.arguments }
                          })}\n\n`);
                        }
                      }
                    }
                  }
                }
              }
            });

            proxyRes.on('error', () => { try { clientRes.end(); } catch (e) {} });
            proxyRes.on('end', () => { try { clientRes.end(); } catch (e) {} });
          } else {
            // Non-stream chat completions
            let buffer = '';
            proxyRes.on('data', c => buffer += c.toString('utf8'));
            proxyRes.on('end', () => {
              let json;
              try { json = JSON.parse(buffer); } catch (e) {
                clientRes.writeHead(500, { 'Content-Type': 'application/json' });
                return clientRes.end(JSON.stringify({ type: 'error', error: { message: buffer } }));
              }
              const choice = json.choices && json.choices[0];
              const msg = choice?.message || {};
              const content = [];
              if (msg.content) content.push({ type: 'text', text: msg.content });
              if (Array.isArray(msg.tool_calls)) {
                for (const tc of msg.tool_calls) {
                  let parsed = {};
                  try { parsed = JSON.parse(tc.function.arguments); } catch (e) {}
                  content.push({ type: 'tool_use', id: tc.id, name: tc.function.name, input: parsed });
                }
              }
              const resObj = {
                id: 'msg_' + (json.id || crypto.randomUUID()).replace('chatcmpl-', ''),
                type: 'message',
                role: 'assistant',
                content: content,
                model: clientModel,
                stop_reason: (msg.tool_calls && msg.tool_calls.length > 0) ? 'tool_use' : 'end_turn',
                stop_sequence: null,
                usage: {
                  input_tokens: json.usage?.prompt_tokens || 0,
                  output_tokens: json.usage?.completion_tokens || 1
                }
              };
              const outStr = JSON.stringify(resObj);
              clientRes.writeHead(200, {
                'Content-Type': 'application/json',
                'Content-Length': Buffer.byteLength(outStr)
              });
              clientRes.end(outStr);
            });
          }
        } else {
          // OpenCode Responses stream to Anthropic SSE
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

  // Handle Grok CLI and standard OpenAI /responses endpoint
  const chunks = [];
  clientReq.on('data', (chunk) => {
    chunks.push(chunk);
  });

  clientReq.on('end', () => {
    const rawBody = Buffer.concat(chunks).toString('utf8');
    let finalBody = rawBody;
    let targetBase = '/zen/go/v1';

    if (rawBody.trim()) {
      try {
        const parsed = JSON.parse(rawBody);
        let requestedModel = parsed.model || '';

        if (requestedModel === 'muse-spark-1.3-free' || requestedModel === 'claude-muse-spark-1.3-free' || requestedModel.includes('contributor-free') || requestedModel.endsWith('-free')) {
          parsed.model = 'muse-spark-1.3-contributor-free';
          targetBase = '/zen/v1';
        } else if (requestedModel.includes('muse-spark')) {
          parsed.model = 'muse-spark-1.3-contributor';
          targetBase = '/zen/go/v1';
        } else if (requestedModel.startsWith('claude-')) {
          const raw = requestedModel.slice(7);
          if (raw === 'muse-spark-1.3-free' || raw === 'muse-spark-1.3-contributor-free') {
            parsed.model = 'muse-spark-1.3-contributor-free';
            targetBase = '/zen/v1';
          } else if (raw === 'muse-spark-1.3' || raw === 'muse-spark-1.3-contributor') {
            parsed.model = 'muse-spark-1.3-contributor';
            targetBase = '/zen/go/v1';
          } else {
            parsed.model = raw;
            targetBase = GO_MODELS_SET.has(raw) ? '/zen/go/v1' : '/zen/v1';
          }
        } else {
          targetBase = GO_MODELS_SET.has(requestedModel) ? '/zen/go/v1' : '/zen/v1';
        }

        applyOpenCodeHeaders(headers, clientReq.headers, parsed);
        finalBody = JSON.stringify(parsed);
      } catch (e) {}
    } else {
      applyOpenCodeHeaders(headers, clientReq.headers, null);
    }

    headers['content-length'] = Buffer.byteLength(finalBody);

    const targetPath = `${targetBase}${cleanPath}`;
    const options = {
      hostname: TARGET_HOST,
      port: 443,
      path: targetPath,
      method: clientReq.method,
      headers: headers
    };

    const proxyReq = https.request(options, (proxyRes) => {
      if (proxyRes.statusCode >= 400) {
        let errChunks = [];
        proxyRes.on('data', c => errChunks.push(c));
        proxyRes.on('end', () => {
          if (proxyRes.statusCode >= 400) {
            const errBody = Buffer.concat(errChunks).toString('utf8');
            try {
              fs.appendFileSync('C:\\Users\\USER\\.grok\\proxy-debug.log', `[${new Date().toISOString()}] Upstream Error [${proxyRes.statusCode}]: ${errBody.slice(0, 500)}\n`);
              fs.writeFileSync('C:\\Users\\USER\\.grok\\last-failed-request.json', JSON.stringify({
                time: new Date().toISOString(),
                statusCode: proxyRes.statusCode,
                targetPath,
                headers,
                payload: outgoingPayload,
                error: errBody
              }, null, 2));
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
