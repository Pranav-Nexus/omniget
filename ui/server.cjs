const http = require('http');
const { exec } = require('child_process');
const path = require('path');
const fs = require('fs');

const PORT = 3001;
const BRIDGE_SCRIPT = path.resolve(__dirname, 'bridge.ps1');

const MIME_TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.json': 'application/json',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2'
};

// Cache static heavy endpoints
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
    if (line.startsWith('---') || !isParsing || !line.trim()) continue;

    const parts = line.trim().split(/\s{2,}/);
    if (parts.length >= 3) {
      packages.push({
        name: parts[0],
        id: parts[1],
        version: parts[2],
        availableVersion: parts[3] || parts[2],
        source: parts[4] || 'winget',
        publisher: parts[1].includes('.') ? parts[1].split('.')[0] : 'Installed Package'
      });
    }
  }

  return packages;
}

const server = http.createServer(async (req, res) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    res.writeHead(204);
    return res.end();
  }

  const url = new URL(req.url, `http://localhost:${PORT}`);

  try {
    // 1. Live Hardware System Telemetry
    if (url.pathname === '/api/system-info') {
      const resData = await runBridge('system-info');
      const info = extractJson(resData.output);
      res.writeHead(200, { 'Content-Type': 'application/json' });
      return res.end(JSON.stringify({ success: true, info }));
    }

    // 2. Live Process Explorer
    if (url.pathname === '/api/processes') {
      const resData = await runBridge('processes');
      const processes = extractJson(resData.output) || [];
      res.writeHead(200, { 'Content-Type': 'application/json' });
      return res.end(JSON.stringify({ success: true, processes }));
    }

    // 3. Process Kill Endpoint
    if (url.pathname === '/api/processes/kill' && req.method === 'POST') {
      let body = '';
      req.on('data', chunk => body += chunk);
      req.on('end', async () => {
        const { pid } = JSON.parse(body || '{}');
        const resData = await runBridge('process-kill', pid);
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ success: resData.success }));
      });
      return;
    }

    // 4. Hardware Privacy Audit Logs
    if (url.pathname === '/api/privacy/logs') {
      const resData = await runBridge('privacy-logs');
      const logs = extractJson(resData.output) || [];
      res.writeHead(200, { 'Content-Type': 'application/json' });
      return res.end(JSON.stringify({ success: true, logs }));
    }

    // Installed Packages
    if (url.pathname === '/api/installed') {
      if (cache['/api/installed'] && (Date.now() - cache['/api/installed'].timestamp < CACHE_TTL_MS)) {
        res.writeHead(200, { 'Content-Type': 'application/json' });
        return res.end(cache['/api/installed'].data);
      }

      const resData = await runBridge('installed');
      let packages = extractJson(resData.output);
      if (!packages) {
        packages = parseInstalledList(resData.output);
      }

      const jsonStr = JSON.stringify({ success: true, packages });
      cache['/api/installed'] = { timestamp: Date.now(), data: jsonStr };

      res.writeHead(200, { 'Content-Type': 'application/json' });
      return res.end(jsonStr);
    }

    // Outdated Packages
    if (url.pathname === '/api/outdated') {
      if (cache['/api/outdated'] && (Date.now() - cache['/api/outdated'].timestamp < CACHE_TTL_MS)) {
        res.writeHead(200, { 'Content-Type': 'application/json' });
        return res.end(cache['/api/outdated'].data);
      }

      const resData = await runBridge('outdated');
      let updates = extractJson(resData.output) || [];

      const jsonStr = JSON.stringify({ success: true, updates });
      cache['/api/outdated'] = { timestamp: Date.now(), data: jsonStr };

      res.writeHead(200, { 'Content-Type': 'application/json' });
      return res.end(jsonStr);
    }

    // Doctor Diagnostics
    if (url.pathname === '/api/doctor') {
      const resData = await runBridge('doctor');
      let checks = extractJson(resData.output) || [];
      if (!Array.isArray(checks)) checks = [checks];
      const jsonStr = JSON.stringify({ success: true, checks });
      res.writeHead(200, { 'Content-Type': 'application/json' });
      return res.end(jsonStr);
    }

    // Services
    if (url.pathname === '/api/services') {
      const resData = await runBridge('services');
      let svcs = extractJson(resData.output) || [];
      if (!Array.isArray(svcs)) svcs = [svcs];
      const jsonStr = JSON.stringify({ success: true, services: svcs });
      res.writeHead(200, { 'Content-Type': 'application/json' });
      return res.end(jsonStr);
    }

    // Startup Programs
    if (url.pathname === '/api/startup') {
      const resData = await runBridge('startup');
      let starts = extractJson(resData.output) || [];
      if (!Array.isArray(starts)) starts = [starts];
      const jsonStr = JSON.stringify({ success: true, startup: starts });
      res.writeHead(200, { 'Content-Type': 'application/json' });
      return res.end(jsonStr);
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

    // Serve Static UI Frontend Files
    if (!url.pathname.startsWith('/api/')) {
      const distDir = path.resolve(__dirname, 'dist');
      let targetFile = path.join(distDir, url.pathname === '/' ? 'index.html' : url.pathname);
      if (!fs.existsSync(targetFile) || fs.statSync(targetFile).isDirectory()) {
        targetFile = path.join(distDir, 'index.html');
      }

      if (fs.existsSync(targetFile)) {
        const ext = path.extname(targetFile).toLowerCase();
        const contentType = MIME_TYPES[ext] || 'application/octet-stream';
        res.writeHead(200, { 'Content-Type': contentType });
        return fs.createReadStream(targetFile).pipe(res);
      }
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
