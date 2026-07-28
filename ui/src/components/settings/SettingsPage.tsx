import React, { useState, useEffect } from 'react';
import { Settings, Shield, Palette, ArrowUp, ArrowDown, Save, Laptop, Moon, Sun, CheckCircle2, Cpu, Copy, Terminal, Bot } from 'lucide-react';
import { useTheme } from '../../context/ThemeContext';
import { ConfigManager, SharedOmniGetConfig } from '../../services/configManager';
import { CliBridge } from '../../services/cliBridge';

export const SettingsPage: React.FC = () => {
  const { theme, setTheme, accentColor, setAccentColor } = useTheme();
  const [priorities, setPriorities] = useState<string[]>(['winget', 'choco']);
  const [userScopeInstall, setUserScopeInstall] = useState(true);
  const [savedMsg, setSavedMsg] = useState(false);
  const [copiedMcp, setCopiedMcp] = useState(false);

  useEffect(() => {
    // Load config and query installed PMs
    Promise.all([
      ConfigManager.loadConfig(),
      CliBridge.fetchDoctorChecks()
    ]).then(([cfg, checks]) => {
      const activePms = checks
        .filter(c => c.category === 'Installed Package Manager' || (c.category === 'Package Manager' && c.status === 'healthy'))
        .map(c => {
          if (c.id.includes('winget')) return 'winget';
          if (c.id.includes('choco')) return 'choco';
          if (c.id.includes('scoop')) return 'scoop';
          if (c.id.includes('pip')) return 'pip';
          if (c.id.includes('npm')) return 'npm';
          if (c.id.includes('cargo')) return 'cargo';
          return c.id;
        });

      if (cfg.Priority) {
        const filtered = cfg.Priority.filter(pm => activePms.length === 0 || activePms.includes(pm.toLowerCase()));
        setPriorities(filtered.length > 0 ? filtered : activePms);
      } else {
        setPriorities(activePms.length > 0 ? activePms : ['winget', 'choco']);
      }

      if (cfg.UserScopeInstall !== undefined) setUserScopeInstall(cfg.UserScopeInstall);
    });
  }, []);

  const movePriority = (index: number, direction: 'up' | 'down') => {
    const newArr = [...priorities];
    const targetIdx = direction === 'up' ? index - 1 : index + 1;
    if (targetIdx < 0 || targetIdx >= newArr.length) return;
    const temp = newArr[index];
    newArr[index] = newArr[targetIdx];
    newArr[targetIdx] = temp;
    setPriorities(newArr);
  };

  const handleSaveConfig = async () => {
    const newConfig: SharedOmniGetConfig = {
      Priority: priorities,
      UserScopeInstall: userScopeInstall
    };
    await ConfigManager.saveConfig(newConfig);
    setSavedMsg(true);
    setTimeout(() => setSavedMsg(false), 3000);
  };

  const mcpConfigSnippet = `{
  "mcpServers": {
    "omniget": {
      "command": "node",
      "args": ["C:/Users/harih/Documents/Open_Source_Contribution/My Projects/Install Script/ui/mcp-server.cjs"]
    }
  }
}`;

  const copyMcpConfig = () => {
    navigator.clipboard.writeText(mcpConfigSnippet);
    setCopiedMcp(true);
    setTimeout(() => setCopiedMcp(false), 2500);
  };

  const accentOptions = [
    { name: 'Windows Blue', color: '#005FB8' },
    { name: 'Fluent Indigo', color: '#6366F1' },
    { name: 'Emerald Green', color: '#10B981' },
    { name: 'Amethyst Purple', color: '#8B5CF6' },
    { name: 'Crimson Rose', color: '#F43F5E' },
  ];

  return (
    <div className="p-6 md:p-8 space-y-8 overflow-y-auto h-full max-w-4xl">
      {/* Header */}
      <div className="flex items-center justify-between border-b border-slate-200 dark:border-fluent-border-dark pb-6">
        <div>
          <h1 className="text-xl font-bold text-slate-900 dark:text-white flex items-center space-x-2">
            <Settings className="w-6 h-6 text-blue-500 dark:text-blue-400" />
            <span>Settings & Shared Configuration</span>
          </h1>
          <p className="text-xs text-slate-600 dark:text-gray-400 mt-1">
            Manages priority cascade order, theme preferences, and Model Context Protocol (MCP) AI integration.
          </p>
        </div>

        <button
          onClick={handleSaveConfig}
          className="px-5 py-2.5 rounded-xl bg-blue-600 hover:bg-blue-500 text-white font-semibold text-xs flex items-center space-x-2 shadow-lg shadow-blue-600/30 transition-all"
        >
          <Save className="w-4 h-4" />
          <span>{savedMsg ? 'Config Safely Submitted!' : 'Save & Submit Config'}</span>
        </button>
      </div>

      {savedMsg && (
        <div className="p-4 rounded-xl bg-emerald-500/10 dark:bg-emerald-500/20 text-emerald-700 dark:text-emerald-300 border border-emerald-500/30 text-xs flex items-center space-x-2 animate-in fade-in">
          <CheckCircle2 className="w-4 h-4 text-emerald-500 dark:text-emerald-400" />
          <span>Configuration saved successfully to `C:\Users\harih\.omniget_config.json`!</span>
        </div>
      )}

      {/* Section 1: Package Manager Priority Cascade (Installed PMs Only) */}
      <div className="p-6 rounded-2xl bg-white dark:bg-fluent-bg-cardDark border border-slate-200 dark:border-fluent-border-dark space-y-4 shadow-sm dark:shadow-mica">
        <div className="flex items-center space-x-2 text-sm font-bold text-slate-900 dark:text-white">
          <Shield className="w-4 h-4 text-blue-500 dark:text-blue-400" />
          <span>Installed Package Manager Priority Cascade</span>
        </div>
        <p className="text-xs text-slate-600 dark:text-gray-400">
          Showing only package managers installed on this system. OmniGet attempts installation starting with the highest priority manager.
        </p>

        <div className="space-y-2 max-w-md pt-2">
          {priorities.map((item, idx) => (
            <div
              key={item}
              className="p-3.5 rounded-xl bg-slate-50 dark:bg-white/5 border border-slate-200 dark:border-white/10 flex items-center justify-between text-xs"
            >
              <div className="flex items-center space-x-3">
                <span className="w-5 h-5 rounded-full bg-blue-500/20 text-blue-600 dark:text-blue-400 font-bold flex items-center justify-center text-[10px]">
                  {idx + 1}
                </span>
                <span className="font-mono uppercase font-bold text-slate-900 dark:text-white">{item}</span>
              </div>

              <div className="flex items-center space-x-1">
                <button
                  disabled={idx === 0}
                  onClick={() => movePriority(idx, 'up')}
                  className="p-1 rounded hover:bg-slate-200 dark:hover:bg-white/10 text-slate-500 dark:text-gray-400 hover:text-slate-900 dark:hover:text-white disabled:opacity-30"
                >
                  <ArrowUp className="w-4 h-4" />
                </button>
                <button
                  disabled={idx === priorities.length - 1}
                  onClick={() => movePriority(idx, 'down')}
                  className="p-1 rounded hover:bg-slate-200 dark:hover:bg-white/10 text-slate-500 dark:text-gray-400 hover:text-slate-900 dark:hover:text-white disabled:opacity-30"
                >
                  <ArrowDown className="w-4 h-4" />
                </button>
              </div>
            </div>
          ))}
        </div>

        <div className="pt-4 border-t border-slate-100 dark:border-white/5 flex items-center justify-between">
          <div>
            <span className="text-xs font-semibold text-slate-900 dark:text-white block">User-Scope Admin Bypass</span>
            <span className="text-[11px] text-slate-500 dark:text-gray-400">Run non-elevated user-scope installs to bypass UAC administrative prompts</span>
          </div>
          <input
            type="checkbox"
            checked={userScopeInstall}
            onChange={(e) => setUserScopeInstall(e.target.checked)}
            className="w-4 h-4 rounded border-slate-300 dark:border-gray-600 bg-slate-100 dark:bg-gray-800 text-blue-600 dark:text-blue-500 focus:ring-blue-500"
          />
        </div>
      </div>

      {/* Section 2: Model Context Protocol (MCP) AI Server Integration */}
      <div className="p-6 rounded-2xl bg-white dark:bg-fluent-bg-cardDark border border-slate-200 dark:border-fluent-border-dark space-y-4 shadow-sm dark:shadow-mica">
        <div className="flex items-center justify-between">
          <div className="flex items-center space-x-2 text-sm font-bold text-slate-900 dark:text-white">
            <Bot className="w-4.5 h-4.5 text-blue-500 dark:text-blue-400" />
            <span>Official OmniGet Model Context Protocol (MCP) Server</span>
          </div>
          <span className="px-2.5 py-0.5 rounded-full text-[10px] font-mono font-bold bg-emerald-500/15 text-emerald-600 dark:text-emerald-400 border border-emerald-500/30 uppercase">
            Server Ready (Stdio / JSON-RPC 2.0)
          </span>
        </div>

        <p className="text-xs text-slate-600 dark:text-gray-400 leading-relaxed">
          Connect external AI agents (Claude Desktop, Antigravity, ChatGPT, or custom LLMs) directly to OmniGet. Exposes real-time package installation, search, process control, system telemetry, and privacy audit tools.
        </p>

        <div className="space-y-2 pt-2">
          <div className="flex items-center justify-between">
            <span className="text-xs font-semibold text-slate-800 dark:text-gray-200">Claude Desktop / Antigravity MCP Config Snippet:</span>
            <button
              onClick={copyMcpConfig}
              className="px-3 py-1 rounded-lg bg-blue-600 hover:bg-blue-500 text-white text-xs font-semibold flex items-center space-x-1 shadow-sm transition-all"
            >
              <Copy className="w-3.5 h-3.5" />
              <span>{copiedMcp ? 'Copied to Clipboard!' : 'Copy Config JSON'}</span>
            </button>
          </div>

          <pre className="p-4 rounded-xl bg-slate-900 text-slate-100 font-mono text-xs overflow-x-auto border border-slate-700">
            {mcpConfigSnippet}
          </pre>
        </div>
      </div>

      {/* Section 3: System Theme & Accent Colors */}
      <div className="p-6 rounded-2xl bg-white dark:bg-fluent-bg-cardDark border border-slate-200 dark:border-fluent-border-dark space-y-4 shadow-sm dark:shadow-mica">
        <div className="flex items-center space-x-2 text-sm font-bold text-slate-900 dark:text-white">
          <Palette className="w-4 h-4 text-indigo-500 dark:text-indigo-400" />
          <span>UI Theme & Windows Accent Sync</span>
        </div>

        <div className="space-y-4 pt-2">
          <div>
            <label className="text-xs text-slate-700 dark:text-gray-300 font-medium block mb-2">Appearance Mode:</label>
            <div className="flex items-center space-x-3">
              {[
                { id: 'system', label: 'System Default', icon: Laptop },
                { id: 'dark', label: 'Dark Mode', icon: Moon },
                { id: 'light', label: 'Light Mode', icon: Sun },
              ].map((item) => {
                const Icon = item.icon;
                return (
                  <button
                    key={item.id}
                    onClick={() => setTheme(item.id as any)}
                    className={`px-4 py-2 rounded-xl text-xs font-semibold flex items-center space-x-2 border transition-all ${
                      theme === item.id
                        ? 'bg-blue-600 text-white border-blue-500 shadow-md'
                        : 'bg-slate-100 dark:bg-white/5 text-slate-700 dark:text-gray-400 border-slate-200 dark:border-white/10 hover:text-slate-900 dark:hover:text-white'
                    }`}
                  >
                    <Icon className="w-3.5 h-3.5" />
                    <span>{item.label}</span>
                  </button>
                );
              })}
            </div>
          </div>

          <div>
            <label className="text-xs text-slate-700 dark:text-gray-300 font-medium block mb-2">Windows Accent Palette:</label>
            <div className="flex items-center space-x-3">
              {accentOptions.map((opt) => (
                <button
                  key={opt.color}
                  onClick={() => setAccentColor(opt.color)}
                  style={{ backgroundColor: opt.color }}
                  className={`w-8 h-8 rounded-full border-2 transition-transform hover:scale-110 ${
                    accentColor === opt.color ? 'border-slate-900 dark:border-white scale-110 shadow-lg' : 'border-transparent'
                  }`}
                  title={opt.name}
                />
              ))}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};
