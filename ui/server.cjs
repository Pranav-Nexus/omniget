const http = require('http');
const { exec } = require('child_process');
const path = require('path');

const PORT = 3001;
const BRIDGE_SCRIPT = path.resolve(__dirname, 'bridge.ps1');

// Cache only static heavy endpoints (installed list, outdated list)
const cache = {};
const CACHE_TTL_MS = 10000;

function runBridge(action, param1 = '', param2 = '', param3 = '') {
  return new Promise((resolve) => {
    const cmd = `powershell -ExecutionPolicy Bypass -NoProfile -File "${BRIDGE_SCRIPT}" ${action} ${param1} ${param2} ${param3}`;
    exec(cmd, { maxBuffer: 1024 * 1024 * 15 }, (error, stdout, stderr) => {
      if (error && !stdout) {
        return resolve({ success: false, output: stderr || error.message });
      }
      resolve({ success: true, output: stdout });
    });
  });
}

function extractJson(output) {
  const match = output.match(/---JSON_START---([\s\S]*?)---JSON_END---/);
  if (match && match[1]) {
    try {
      return JSON.parse(match[1].trim());
    } catch (e) {}
  }
  return null;
}

function parseInstalledList(output) {
  const packages = [];
  const lines = output.split(/\r?\n/);
  let isParsing = false;

  for (const line of lines) {
    if (line.includes('Name') && line.includes('Id') && line.includes('Version')) {
      isParsing = true;
      continue;
    }
    if (isParsing && line.startsWith('---')) continue;
    if (isParsing && line.trim()) {
      const match = line.match(/^(.+?)\s{2,}([a-zA-Z0-9\-\._\:]+)\s{2,}([^\s]+)\s{2,}([^\s]+)/);
      if (match) {
        packages.push({
          name: match[1].trim(),
          id: match[2].trim(),
          version: match[3].trim(),
          source: (match[4].trim().toLowerCase() || 'winget'),
          publisher: match[2].includes('.') ? match[2].split('.')[0] : 'Installed Package'
        });
      } else {
        const parts = line.trim().split(/\s+/);
        if (parts.length >= 3) {
          packages.push({
            name: parts[0],
            id: parts[1] || parts[0],
            version: parts[2] || '1.0.0',
            source: 'winget',
            publisher: 'Package'
          });
        }
      }
    }
  }

  if (packages.length === 0) {
    const jsonMatch = extractJson(output);
    if (Array.isArray(jsonMatch)) return jsonMatch;
  }

  return packages;
}

function parseSearchResults(output) {
  const results = [];
  const lines = output.split(/\r?\n/);
  let isParsing = false;

  for (const line of lines) {
    if (line.includes('Name') && line.includes('Id')) {
      isParsing = true;
      continue;
    }
    if (isParsing && line.startsWith('---')) continue;
    if (isParsing && line.trim()) {
      const match = line.match(/^(.+?)\s{2,}([a-zA-Z0-9\-\._\:]+)\s{2,}([^\s]+)\s{2,}([^\s]+)/);
      if (match) {
        results.push({
          id: match[2].trim(),
          name: match[1].trim(),
          publisher: match[2].includes('.') ? match[2].split('.')[0] : 'Community Package',
          description: `Package ${match[1].trim()} available via multi-repo registry.`,
          version: match[3].trim(),
          source: match[4].trim().toLowerCase() || 'winget',
          sourcesAvailable: ['winget', 'choco', 'scoop'],
          category: 'Development',
          rating: 4.8
        });
      }
    }
  }
  return results;
}

const server = http.createServer(async (req, res) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    res.writeHead(200);
    return res.end();
  }

  const url = new URL(req.url, `http://localhost:${PORT}`);
  const cacheKey = url.pathname + url.search;

  // Never cache real-time live telemetry endpoints
  const liveRealtimeEndpoints = ['/api/system-info', '/api/processes', '/api/privacy/logs'];
  if (req.method === 'GET' && !liveRealtimeEndpoints.includes(url.pathname) && cache[cacheKey] && (Date.now() - cache[cacheKey].timestamp < CACHE_TTL_MS)) {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    return res.end(cache[cacheKey].body);
  }

  try {
    // 0. Live System Specs & Telemetry Endpoint (Real-time Task Manager counters)
    if (url.pathname === '/api/system-info') {
      const resData = await runBridge('system-info');
      const info = extractJson(resData.output) || {};
      res.writeHead(200, { 'Content-Type': 'application/json' });
      return res.end(JSON.stringify({ success: true, info }));
    }

    // Running Processes
    if (url.pathname === '/api/processes') {
      const resData = await runBridge('processes');
      let processes = extractJson(resData.output) || [];
      if (!Array.isArray(processes)) processes = [processes];
      res.writeHead(200, { 'Content-Type': 'application/json' });
      return res.end(JSON.stringify({ success: true, processes }));
    }

    if (url.pathname === '/api/processes/kill' && req.method === 'POST') {
      let body = '';
      req.on('data', chunk => body += chunk);
      req.on('end', async () => {
        const { pid } = JSON.parse(body || '{}');
        const resData = await runBridge('process-kill', pid);
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ success: resData.success, command: `Stop-Process -Id ${pid}`, output: resData.output }));
      });
      return;
    }

    // Privacy Access Logs (Webcam, Microphone, Location handles)
    if (url.pathname === '/api/privacy/logs') {
      const resData = await runBridge('privacy-logs');
      let logs = extractJson(resData.output) || [];
      if (!Array.isArray(logs)) logs = [logs];
      res.writeHead(200, { 'Content-Type': 'application/json' });
      return res.end(JSON.stringify({ success: true, logs }));
    }

    // Windows Services
    if (url.pathname === '/api/services') {
      const resData = await runBridge('services');
      let services = extractJson(resData.output) || [];
      if (!Array.isArray(services)) services = [services];
      res.writeHead(200, { 'Content-Type': 'application/json' });
      return res.end(JSON.stringify({ success: true, services }));
    }

    // Startup Applications
    if (url.pathname === '/api/startup') {
      const resData = await runBridge('startup');
      let startup = extractJson(resData.output) || [];
      if (!Array.isArray(startup)) startup = [startup];
      res.writeHead(200, { 'Content-Type': 'application/json' });
      return res.end(JSON.stringify({ success: true, startup }));
    }

    // Installed Library
    if (url.pathname === '/api/installed') {
      const resData = await runBridge('installed');
      const pkgs = parseInstalledList(resData.output);
      const jsonStr = JSON.stringify({ success: true, command: 'omniget list', packages: pkgs, raw: resData.output });
      cache[cacheKey] = { timestamp: Date.now(), body: jsonStr };
      res.writeHead(200, { 'Content-Type': 'application/json' });
      return res.end(jsonStr);
    }

    // Outdated Updates Dashboard
    if (url.pathname === '/api/outdated') {
      const resData = await runBridge('outdated');
      let updates = extractJson(resData.output) || [];
      if (!Array.isArray(updates)) updates = [updates];
      const jsonStr = JSON.stringify({ success: true, command: 'omniget upgrade (outdated scan)', updates, raw: resData.output });
      cache[cacheKey] = { timestamp: Date.now(), body: jsonStr };
      res.writeHead(200, { 'Content-Type': 'application/json' });
      return res.end(jsonStr);
    }

    // Search
    if (url.pathname === '/api/search') {
      const query = url.searchParams.get('q') || '';
      if (!query.trim()) {
        res.writeHead(200, { 'Content-Type': 'application/json' });
        return res.end(JSON.stringify({ success: true, command: 'omniget search', results: [] }));
      }
      const resData = await runBridge('search', `"${query}"`);
      const results = parseSearchResults(resData.output);
      const jsonStr = JSON.stringify({ success: true, command: `omniget search ${query}`, results, raw: resData.output });
      res.writeHead(200, { 'Content-Type': 'application/json' });
      return res.end(jsonStr);
    }

    // Doctor System Audit
    if (url.pathname === '/api/doctor') {
      const resData = await runBridge('doctor');
      let checks = extractJson(resData.output) || [];
      if (!Array.isArray(checks)) checks = [checks];
      const jsonStr = JSON.stringify({ success: true, command: 'omniget doctor', checks, raw: resData.output });
      cache[cacheKey] = { timestamp: Date.now(), body: jsonStr };
      res.writeHead(200, { 'Content-Type': 'application/json' });
      return res.end(jsonStr);
    }

    // Doctor Dismiss
    if (url.pathname === '/api/doctor/dismiss' && req.method === 'POST') {
      let body = '';
      req.on('data', chunk => body += chunk);
      req.on('end', async () => {
        const { id } = JSON.parse(body || '{}');
        const resData = await runBridge('doctor-dismiss', id);
        delete cache['/api/doctor'];
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ success: true, command: `omniget doctor dismiss ${id}`, output: resData.output }));
      });
      return;
    }

    // Doctor Snooze
    if (url.pathname === '/api/doctor/snooze' && req.method === 'POST') {
      let body = '';
      req.on('data', chunk => body += chunk);
      req.on('end', async () => {
        const { id, hours } = JSON.parse(body || '{}');
        const resData = await runBridge('doctor-snooze', id, hours);
        delete cache['/api/doctor'];
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ success: true, command: `omniget doctor snooze ${id} ${hours}`, output: resData.output }));
      });
      return;
    }

    // Doctor Restore
    if (url.pathname === '/api/doctor/restore' && req.method === 'POST') {
      let body = '';
      req.on('data', chunk => body += chunk);
      req.on('end', async () => {
        const { id } = JSON.parse(body || '{}');
        const resData = await runBridge('doctor-restore', id);
        delete cache['/api/doctor'];
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ success: true, command: `omniget doctor restore ${id}`, output: resData.output }));
      });
      return;
    }

    // Environment Variables
    if (url.pathname === '/api/env') {
      const resData = await runBridge('env');
      let vars = extractJson(resData.output) || [];
      if (!Array.isArray(vars)) vars = [vars];
      const jsonStr = JSON.stringify({ success: true, vars });
      res.writeHead(200, { 'Content-Type': 'application/json' });
      return res.end(jsonStr);
    }

    // Path Entries
    if (url.pathname === '/api/path') {
      const resData = await runBridge('path');
      let entries = extractJson(resData.output) || [];
      if (!Array.isArray(entries)) entries = [entries];
      const jsonStr = JSON.stringify({ success: true, entries });
      res.writeHead(200, { 'Content-Type': 'application/json' });
      return res.end(jsonStr);
    }

    // Shell Aliases
    if (url.pathname === '/api/alias') {
      const resData = await runBridge('alias');
      let aliases = extractJson(resData.output) || [];
      if (!Array.isArray(aliases)) aliases = [aliases];
      const jsonStr = JSON.stringify({ success: true, aliases });
      res.writeHead(200, { 'Content-Type': 'application/json' });
      return res.end(jsonStr);
    }

    // Generic Action Execution
    if (url.pathname === '/api/action' && req.method === 'POST') {
      let body = '';
      req.on('data', chunk => body += chunk);
      req.on('end', async () => {
        const { action, id, flags } = JSON.parse(body || '{}');
        let paramStr = id || '';
        if (flags?.pm) paramStr += ` --pm ${flags.pm}`;
        if (flags?.silent) paramStr += ` --silent`;

        const resData = await runBridge(action, paramStr);
        delete cache['/api/installed'];
        delete cache['/api/outdated'];

        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({
          success: resData.success,
          command: `omniget ${action} ${paramStr}`,
          output: resData.output
        }));
      });
      return;
    }

    res.writeHead(404, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: 'Endpoint not found' }));
  } catch (err) {
    res.writeHead(500, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: err.message }));
  }
});

server.listen(PORT, () => {
  console.log(`[OmniGet Bridge Server] Running live execution engine on http://localhost:${PORT}`);
});
