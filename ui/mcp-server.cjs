#!/usr/bin/env node

/**
 * OmniGet Official MCP (Model Context Protocol) Server
 * Enables LLM agents (Claude Desktop, Antigravity, ChatGPT, Custom Agents)
 * to interact with OmniGet package management, system telemetry, process control, and privacy audits.
 */

const { exec } = require('child_process');
const path = require('path');
const readline = require('readline');

const BRIDGE_SCRIPT = path.resolve(__dirname, 'bridge.ps1');

function runBridge(action, params = '') {
  return new Promise((resolve) => {
    const cmd = `powershell -ExecutionPolicy Bypass -NoProfile -File "${BRIDGE_SCRIPT}" ${action} ${params}`;
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

// MCP Capabilities Definition
const SERVER_INFO = {
  name: 'omniget-mcp-server',
  version: '1.0.0'
};

const TOOLS = [
  {
    name: 'omniget_system_telemetry',
    description: 'Query real-time hardware telemetry: CPU load, Dual GPUs, VRAM, RAM capacity, temperatures, and storage disks.',
    inputSchema: {
      type: 'object',
      properties: {
        timeTravelHoursAgo: { type: 'number', description: 'Optional hours ago (0 for live, 1 to 72 for historical time travel)' }
      }
    }
  },
  {
    name: 'omniget_install',
    description: 'Install software packages using WinGet, Chocolatey, or Scoop via OmniGet priority cascade.',
    inputSchema: {
      type: 'object',
      properties: {
        packageId: { type: 'string', description: 'Package ID (e.g. Microsoft.VisualStudioCode, Git.Git, vlc)' },
        packageManager: { type: 'string', description: 'Optional manager: winget, choco, or scoop' },
        silent: { type: 'boolean', description: 'Run quiet silent installer (default true)' }
      },
      required: ['packageId']
    }
  },
  {
    name: 'omniget_search',
    description: 'Search available software packages across WinGet, Chocolatey, and Scoop repositories.',
    inputSchema: {
      type: 'object',
      properties: {
        query: { type: 'string', description: 'Search term' }
      },
      required: ['query']
    }
  },
  {
    name: 'omniget_list_installed',
    description: 'List all software packages currently installed on the host Windows machine.',
    inputSchema: { type: 'object', properties: {} }
  },
  {
    name: 'omniget_upgrade_outdated',
    description: 'Scan system for outdated software packages available for upgrade.',
    inputSchema: { type: 'object', properties: {} }
  },
  {
    name: 'omniget_doctor_audit',
    description: 'Run live system health audit checking package managers, PATH hygiene, and UAC privilege scope.',
    inputSchema: { type: 'object', properties: {} }
  },
  {
    name: 'omniget_process_control',
    description: 'List running processes or terminate a process by PID.',
    inputSchema: {
      type: 'object',
      properties: {
        action: { type: 'string', enum: ['list', 'kill'], description: 'Action to perform' },
        pid: { type: 'number', description: 'Process ID to kill if action is kill' }
      },
      required: ['action']
    }
  },
  {
    name: 'omniget_privacy_audit',
    description: 'Query privacy access handles (Webcam, Microphone, Location API calls per process).',
    inputSchema: { type: 'object', properties: {} }
  },
  {
    name: 'omniget_env_path',
    description: 'Query or manage Windows Environment Variables and PATH entries.',
    inputSchema: {
      type: 'object',
      properties: {
        type: { type: 'string', enum: ['env', 'path'] },
        action: { type: 'string', enum: ['show', 'add', 'remove'] },
        key: { type: 'string' },
        value: { type: 'string' },
        scope: { type: 'string', enum: ['user', 'system'] }
      },
      required: ['type', 'action']
    }
  }
];

// Handle MCP JSON-RPC requests
async function handleRpcRequest(request) {
  const { id, method, params } = request;

  if (method === 'initialize') {
    return {
      jsonrpc: '2.0',
      id,
      result: {
        protocolVersion: '2024-11-05',
        capabilities: { tools: {}, resources: {} },
        serverInfo: SERVER_INFO
      }
    };
  }

  if (method === 'notifications/initialized') {
    return null; // Notifications require no response
  }

  if (method === 'tools/list') {
    return {
      jsonrpc: '2.0',
      id,
      result: { tools: TOOLS }
    };
  }

  if (method === 'tools/call') {
    const { name, arguments: args } = params;
    let toolResultText = '';

    try {
      if (name === 'omniget_system_telemetry') {
        const resData = await runBridge('system-info');
        const info = extractJson(resData.output) || {};
        toolResultText = JSON.stringify(info, null, 2);
      } 
      else if (name === 'omniget_search') {
        const resData = await runBridge('search', `"${args.query}"`);
        toolResultText = resData.output;
      }
      else if (name === 'omniget_list_installed') {
        const resData = await runBridge('installed');
        toolResultText = resData.output;
      }
      else if (name === 'omniget_upgrade_outdated') {
        const resData = await runBridge('outdated');
        toolResultText = resData.output;
      }
      else if (name === 'omniget_doctor_audit') {
        const resData = await runBridge('doctor');
        toolResultText = resData.output;
      }
      else if (name === 'omniget_install') {
        let cmd = `install ${args.packageId}`;
        if (args.packageManager) cmd += ` --pm ${args.packageManager}`;
        if (args.silent !== false) cmd += ` --silent`;
        const resData = await runBridge(cmd);
        toolResultText = resData.output;
      }
      else if (name === 'omniget_process_control') {
        if (args.action === 'kill' && args.pid) {
          const resData = await runBridge('process-kill', args.pid);
          toolResultText = resData.output;
        } else {
          const resData = await runBridge('processes');
          toolResultText = resData.output;
        }
      }
      else if (name === 'omniget_privacy_audit') {
        const resData = await runBridge('privacy-logs');
        toolResultText = resData.output;
      }
      else if (name === 'omniget_env_path') {
        if (args.type === 'env') {
          const resData = await runBridge('env');
          toolResultText = resData.output;
        } else {
          const resData = await runBridge('path');
          toolResultText = resData.output;
        }
      }
      else {
        throw new Error(`Unknown tool: ${name}`);
      }

      return {
        jsonrpc: '2.0',
        id,
        result: {
          content: [{ type: 'text', text: toolResultText }]
        }
      };
    } catch (err) {
      return {
        jsonrpc: '2.0',
        id,
        error: { code: -32603, message: err.message }
      };
    }
  }

  return {
    jsonrpc: '2.0',
    id,
    error: { code: -32601, message: `Method not found: ${method}` }
  };
}

// Start stdio interface
const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout,
  terminal: false
});

rl.on('line', async (line) => {
  if (!line.trim()) return;
  try {
    const jsonReq = JSON.parse(line.trim());
    const rpcRes = await handleRpcRequest(jsonReq);
    if (rpcRes) {
      process.stdout.write(JSON.stringify(rpcRes) + '\n');
    }
  } catch (e) {
    console.error('MCP Stdio Error:', e);
  }
});
