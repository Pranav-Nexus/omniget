import React, { useState, useEffect } from 'react';
import { Globe, HardDrive, Plus, Trash2, Radio, Check, AlertCircle, Sparkles, RefreshCw } from 'lucide-react';
import { CliBridge } from '../../services/cliBridge';
import { EnvVariable, PathEntry } from '../../types/omniget';

export const EnvPathManager: React.FC = () => {
  const [activeTab, setActiveTab] = useState<'env' | 'path'>('env');
  const [envVars, setEnvVars] = useState<EnvVariable[]>([]);
  const [pathEntries, setPathEntries] = useState<PathEntry[]>([]);
  const [loading, setLoading] = useState(true);

  // New item inputs
  const [newVarName, setNewVarName] = useState('');
  const [newVarValue, setNewVarValue] = useState('');
  const [newPathFolder, setNewPathFolder] = useState('');
  const [scope, setScope] = useState<'user' | 'system'>('user');
  const [broadcastMsg, setBroadcastMsg] = useState<string | null>(null);

  const loadData = async () => {
    setLoading(true);
    if (activeTab === 'env') {
      const vars = await CliBridge.fetchEnvVariables();
      setEnvVars(vars);
    } else {
      const paths = await CliBridge.fetchPathEntries();
      setPathEntries(paths);
    }
    setLoading(false);
  };

  useEffect(() => {
    loadData();
  }, [activeTab]);

  const triggerBroadcast = (action: string) => {
    setBroadcastMsg(`WM_SETTINGCHANGE broadcasted: ${action}`);
    setTimeout(() => setBroadcastMsg(null), 3500);
  };

  const handleAddEnvVar = async () => {
    if (!newVarName.trim() || !newVarValue.trim()) return;
    setLoading(true);
    const success = await CliBridge.setEnvVariable(newVarName.trim(), newVarValue.trim(), scope);
    if (success) {
      triggerBroadcast(`Environment variable '${newVarName}' created`);
      setNewVarName('');
      setNewVarValue('');
      await loadData();
    } else {
      setLoading(false);
    }
  };

  const handleRemoveEnvVar = async (name: string, varScope: 'user' | 'system') => {
    setLoading(true);
    const success = await CliBridge.removeEnvVariable(name, varScope);
    if (success) {
      triggerBroadcast(`Environment variable '${name}' removed`);
      await loadData();
    } else {
      setLoading(false);
    }
  };

  const handleAddPath = async () => {
    if (!newPathFolder.trim()) return;
    setLoading(true);
    const success = await CliBridge.addPathEntry(newPathFolder.trim(), scope);
    if (success) {
      triggerBroadcast(`Folder added to ${scope.toUpperCase()} PATH`);
      setNewPathFolder('');
      await loadData();
    } else {
      setLoading(false);
    }
  };

  const handleRemovePath = async (folder: string, pathScope: 'user' | 'system') => {
    setLoading(true);
    const success = await CliBridge.removePathEntry(folder, pathScope);
    if (success) {
      triggerBroadcast(`Folder removed from PATH`);
      await loadData();
    } else {
      setLoading(false);
    }
  };

  const handlePruneDeadPaths = async () => {
    setLoading(true);
    await CliBridge.pruneDeadPaths();
    triggerBroadcast(`Pruned dead directories from User PATH`);
    await loadData();
  };

  return (
    <div className="p-6 md:p-8 space-y-6 overflow-y-auto h-full">
      {/* Header */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 border-b border-slate-200 dark:border-fluent-border-dark pb-6">
        <div>
          <h1 className="text-xl font-bold text-slate-900 dark:text-white flex items-center space-x-2">
            <Globe className="w-6 h-6 text-blue-500 dark:text-blue-400" />
            <span>Environment & PATH Manager (Live System)</span>
          </h1>
          <p className="text-xs text-slate-600 dark:text-gray-400 mt-1 font-medium">
            Live orchestrator for Windows User/System Environment variables with instant global `WM_SETTINGCHANGE` broadcast.
          </p>
        </div>

        <div className="flex items-center space-x-3">
          <button
            onClick={loadData}
            disabled={loading}
            className="px-3 py-2 rounded-xl bg-slate-100 dark:bg-white/5 hover:bg-slate-200 dark:hover:bg-white/10 text-slate-700 dark:text-gray-300 text-xs font-medium border border-slate-200 dark:border-white/10 flex items-center space-x-1.5 transition-all"
          >
            <RefreshCw className={`w-3.5 h-3.5 ${loading ? 'animate-spin' : ''}`} />
            <span>Refresh</span>
          </button>

          {broadcastMsg && (
            <div className="px-3 py-1.5 rounded-xl bg-emerald-500/10 dark:bg-emerald-500/20 text-emerald-700 dark:text-emerald-300 border border-emerald-500/30 text-xs flex items-center space-x-2 animate-in fade-in">
              <Radio className="w-3.5 h-3.5 animate-pulse text-emerald-500 dark:text-emerald-400" />
              <span>{broadcastMsg}</span>
            </div>
          )}
        </div>
      </div>

      {/* Sub Tabs Toggle */}
      <div className="flex items-center space-x-3">
        <button
          onClick={() => setActiveTab('env')}
          className={`px-4 py-2 rounded-xl text-xs font-semibold transition-all ${
            activeTab === 'env'
              ? 'bg-blue-600 text-white shadow-md'
              : 'bg-slate-100 dark:bg-white/5 text-slate-700 dark:text-gray-300 hover:text-slate-900 dark:hover:text-white hover:bg-slate-200 dark:hover:bg-white/10'
          }`}
        >
          Environment Variables (`omniget env`)
        </button>

        <button
          onClick={() => setActiveTab('path')}
          className={`px-4 py-2 rounded-xl text-xs font-semibold transition-all ${
            activeTab === 'path'
              ? 'bg-blue-600 text-white shadow-md'
              : 'bg-slate-100 dark:bg-white/5 text-slate-700 dark:text-gray-300 hover:text-slate-900 dark:hover:text-white hover:bg-slate-200 dark:hover:bg-white/10'
          }`}
        >
          PATH Manager (`omniget path`)
        </button>
      </div>

      {/* Tab 1: Environment Variables */}
      {activeTab === 'env' && (
        <div className="space-y-6">
          {/* Add New Variable Bar */}
          <div className="p-4 rounded-2xl bg-white dark:bg-fluent-bg-cardDark border border-slate-200 dark:border-fluent-border-dark space-y-3 shadow-sm">
            <h3 className="text-xs font-bold text-slate-900 dark:text-white">Set Environment Variable</h3>
            <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
              <input
                type="text"
                value={newVarName}
                onChange={(e) => setNewVarName(e.target.value)}
                placeholder="Variable Name (e.g. MY_API_KEY)"
                className="px-3 py-2 text-xs rounded-xl bg-slate-50 dark:bg-black/40 border border-slate-200 dark:border-white/10 text-slate-900 dark:text-white placeholder:text-slate-400 dark:placeholder:text-gray-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
              />

              <input
                type="text"
                value={newVarValue}
                onChange={(e) => setNewVarValue(e.target.value)}
                placeholder="Variable Value"
                className="px-3 py-2 text-xs rounded-xl bg-slate-50 dark:bg-black/40 border border-slate-200 dark:border-white/10 text-slate-900 dark:text-white placeholder:text-slate-400 dark:placeholder:text-gray-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
              />

              <div className="flex items-center space-x-2">
                <select
                  value={scope}
                  onChange={(e) => setScope(e.target.value as any)}
                  className="px-3 py-2 text-xs rounded-xl bg-slate-50 dark:bg-black/40 border border-slate-200 dark:border-white/10 text-slate-900 dark:text-white focus:outline-none"
                >
                  <option value="user">User Scope</option>
                  <option value="system">System Scope (Admin)</option>
                </select>

                <button
                  onClick={handleAddEnvVar}
                  disabled={loading}
                  className="px-4 py-2 rounded-xl bg-blue-600 hover:bg-blue-500 text-white text-xs font-semibold flex items-center space-x-1.5 shadow-md"
                >
                  <Plus className="w-4 h-4" />
                  <span>Set</span>
                </button>
              </div>
            </div>
          </div>

          {/* Table */}
          <div className="rounded-2xl border border-slate-200 dark:border-fluent-border-dark bg-white dark:bg-fluent-bg-dark/50 overflow-hidden shadow-sm dark:shadow-mica">
            <table className="w-full text-left text-xs">
              <thead className="bg-slate-100 dark:bg-white/5 border-b border-slate-200 dark:border-fluent-border-dark text-slate-600 dark:text-gray-400 font-semibold uppercase text-[10px]">
                <tr>
                  <th className="p-4">Name</th>
                  <th className="p-4">Value</th>
                  <th className="p-4">Scope</th>
                  <th className="p-4 text-right">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100 dark:divide-fluent-border-dark text-slate-800 dark:text-gray-200">
                {loading ? (
                  <tr>
                    <td colSpan={4} className="p-8 text-center text-xs text-slate-500 dark:text-gray-400 font-mono">
                      <RefreshCw className="w-5 h-5 animate-spin mx-auto mb-2 text-blue-500 dark:text-blue-400" />
                      Fetching live system environment variables...
                    </td>
                  </tr>
                ) : envVars.length === 0 ? (
                  <tr>
                    <td colSpan={4} className="p-8 text-center text-xs text-slate-500 dark:text-gray-400">
                      No environment variables returned.
                    </td>
                  </tr>
                ) : (
                  envVars.map((v) => (
                    <tr key={`${v.scope}_${v.name}`} className="hover:bg-slate-50 dark:hover:bg-white/5">
                      <td className="p-4 font-mono font-bold text-blue-600 dark:text-blue-400">{v.name}</td>
                      <td className="p-4 font-mono text-slate-700 dark:text-gray-300 truncate max-w-md">{v.value}</td>
                      <td className="p-4">
                        <span className={`px-2 py-0.5 rounded text-[10px] uppercase font-mono font-bold ${
                          v.scope === 'user' ? 'bg-blue-100 text-blue-800 dark:bg-blue-500/20 dark:text-blue-300' : 'bg-purple-100 text-purple-800 dark:bg-purple-500/20 dark:text-purple-300'
                        }`}>
                          {v.scope}
                        </span>
                      </td>
                      <td className="p-4 text-right">
                        <button
                          onClick={() => handleRemoveEnvVar(v.name, v.scope as any)}
                          className="p-1.5 rounded-lg text-red-600 dark:text-red-400 hover:bg-red-100 dark:hover:bg-red-500/20 transition-colors"
                        >
                          <Trash2 className="w-4 h-4" />
                        </button>
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* Tab 2: PATH Manager */}
      {activeTab === 'path' && (
        <div className="space-y-6">
          <div className="p-4 rounded-2xl bg-white dark:bg-fluent-bg-cardDark border border-slate-200 dark:border-fluent-border-dark space-y-3 shadow-sm">
            <div className="flex justify-between items-center">
              <h3 className="text-xs font-bold text-slate-900 dark:text-white">Append Directory to PATH</h3>
              <button
                onClick={handlePruneDeadPaths}
                disabled={loading}
                className="px-3 py-1.5 rounded-xl bg-amber-500/10 dark:bg-amber-500/20 text-amber-700 dark:text-amber-300 text-xs font-semibold border border-amber-500/30 flex items-center space-x-1.5 hover:bg-amber-500 hover:text-white transition-all"
              >
                <Sparkles className="w-3.5 h-3.5" />
                <span>Prune Dead Folders</span>
              </button>
            </div>

            <div className="flex items-center space-x-3">
              <input
                type="text"
                value={newPathFolder}
                onChange={(e) => setNewPathFolder(e.target.value)}
                placeholder="Folder Path (e.g. C:\MyCustomBin)"
                className="flex-1 px-3 py-2 text-xs rounded-xl bg-slate-50 dark:bg-black/40 border border-slate-200 dark:border-white/10 text-slate-900 dark:text-white placeholder:text-slate-400 dark:placeholder:text-gray-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
              />

              <select
                value={scope}
                onChange={(e) => setScope(e.target.value as any)}
                className="px-3 py-2 text-xs rounded-xl bg-slate-50 dark:bg-black/40 border border-slate-200 dark:border-white/10 text-slate-900 dark:text-white focus:outline-none"
              >
                <option value="user">User PATH</option>
                <option value="system">System PATH</option>
              </select>

              <button
                onClick={handleAddPath}
                disabled={loading}
                className="px-4 py-2 rounded-xl bg-blue-600 hover:bg-blue-500 text-white text-xs font-semibold flex items-center space-x-1.5 shadow-md"
              >
                <Plus className="w-4 h-4" />
                <span>Add Path</span>
              </button>
            </div>
          </div>

          <div className="rounded-2xl border border-slate-200 dark:border-fluent-border-dark bg-white dark:bg-fluent-bg-dark/50 overflow-hidden shadow-sm dark:shadow-mica">
            <table className="w-full text-left text-xs">
              <thead className="bg-slate-100 dark:bg-white/5 border-b border-slate-200 dark:border-fluent-border-dark text-slate-600 dark:text-gray-400 font-semibold uppercase text-[10px]">
                <tr>
                  <th className="p-4">Path Directory</th>
                  <th className="p-4">Disk Status</th>
                  <th className="p-4">Scope</th>
                  <th className="p-4 text-right">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100 dark:divide-fluent-border-dark text-slate-800 dark:text-gray-200">
                {loading ? (
                  <tr>
                    <td colSpan={4} className="p-8 text-center text-xs text-slate-500 dark:text-gray-400 font-mono">
                      <RefreshCw className="w-5 h-5 animate-spin mx-auto mb-2 text-blue-500 dark:text-blue-400" />
                      Auditing live PATH directories...
                    </td>
                  </tr>
                ) : pathEntries.length === 0 ? (
                  <tr>
                    <td colSpan={4} className="p-8 text-center text-xs text-slate-500 dark:text-gray-400">
                      No PATH entries returned.
                    </td>
                  </tr>
                ) : (
                  pathEntries.map((pe) => (
                    <tr key={pe.id} className={`hover:bg-slate-50 dark:hover:bg-white/5 ${!pe.exists ? 'bg-red-50 dark:bg-red-500/10' : ''}`}>
                      <td className="p-4 font-mono text-slate-900 dark:text-white">{pe.path}</td>
                      <td className="p-4">
                        {pe.exists ? (
                          <span className="text-[10px] px-2 py-0.5 rounded bg-emerald-100 text-emerald-800 dark:bg-emerald-500/20 dark:text-emerald-400 font-semibold flex items-center space-x-1 w-fit">
                            <Check className="w-3 h-3" />
                            <span>Valid Folder</span>
                          </span>
                        ) : (
                          <span className="text-[10px] px-2 py-0.5 rounded bg-red-100 text-red-800 dark:bg-red-500/20 dark:text-red-400 font-semibold flex items-center space-x-1 w-fit">
                            <AlertCircle className="w-3 h-3" />
                            <span>Dead Path</span>
                          </span>
                        )}
                      </td>
                      <td className="p-4">
                        <span className="text-[10px] px-2 py-0.5 rounded bg-slate-100 dark:bg-white/10 text-slate-700 dark:text-gray-300 uppercase font-mono">
                          {pe.scope}
                        </span>
                      </td>
                      <td className="p-4 text-right">
                        <button
                          onClick={() => handleRemovePath(pe.path, pe.scope as any)}
                          className="p-1.5 rounded-lg text-red-600 dark:text-red-400 hover:bg-red-100 dark:hover:bg-red-500/20 transition-colors"
                        >
                          <Trash2 className="w-4 h-4" />
                        </button>
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        </div>
      )}
    </div>
  );
};
