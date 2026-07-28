import React, { useState, useEffect } from 'react';
import { Terminal, Plus, Trash2, CheckCircle2, RefreshCw } from 'lucide-react';
import { CliBridge } from '../../services/cliBridge';
import { ShellAlias } from '../../types/omniget';

export const AliasManager: React.FC = () => {
  const [aliases, setAliases] = useState<ShellAlias[]>([]);
  const [loading, setLoading] = useState(true);
  const [aliasName, setAliasName] = useState('');
  const [aliasCommand, setAliasCommand] = useState('');
  const [msg, setMsg] = useState<string | null>(null);

  const loadAliases = async () => {
    setLoading(true);
    const liveAliases = await CliBridge.fetchShellAliases();
    setAliases(liveAliases);
    setLoading(false);
  };

  useEffect(() => {
    loadAliases();
  }, []);

  const handleAddAlias = async () => {
    if (!aliasName.trim() || !aliasCommand.trim()) return;
    setLoading(true);
    const success = await CliBridge.addShellAlias(aliasName.trim(), aliasCommand.trim());
    if (success) {
      setMsg(`Registered persistent alias '${aliasName}' in PowerShell $PROFILE`);
      setTimeout(() => setMsg(null), 3500);
      setAliasName('');
      setAliasCommand('');
      await loadAliases();
    } else {
      setLoading(false);
    }
  };

  const handleRemoveAlias = async (name: string) => {
    setLoading(true);
    const success = await CliBridge.removeShellAlias(name);
    if (success) {
      setMsg(`Removed alias '${name}' from $PROFILE`);
      setTimeout(() => setMsg(null), 3500);
      await loadAliases();
    } else {
      setLoading(false);
    }
  };

  return (
    <div className="p-6 md:p-8 space-y-6 overflow-y-auto h-full">
      {/* Header */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 border-b border-fluent-border-dark dark:border-fluent-border-dark light:border-gray-200 pb-6">
        <div>
          <h1 className="text-xl font-bold text-white dark:text-white light:text-gray-900 flex items-center space-x-2">
            <Terminal className="w-6 h-6 text-blue-400" />
            <span>Persistent Shell Alias Manager (Live Profile)</span>
          </h1>
          <p className="text-xs text-gray-400 mt-1">
            Register persistent command function shortcuts directly in your PowerShell `$PROFILE` via `omniget alias`.
          </p>
        </div>

        <div className="flex items-center space-x-3">
          <button
            onClick={loadAliases}
            disabled={loading}
            className="px-3 py-2 rounded-xl bg-white/5 hover:bg-white/10 text-gray-300 text-xs font-medium border border-white/10 flex items-center space-x-1.5 transition-all"
          >
            <RefreshCw className={`w-3.5 h-3.5 ${loading ? 'animate-spin' : ''}`} />
            <span>Refresh Aliases</span>
          </button>

          {msg && (
            <div className="px-3 py-1.5 rounded-xl bg-emerald-500/20 text-emerald-300 border border-emerald-500/30 text-xs flex items-center space-x-2 animate-in fade-in">
              <CheckCircle2 className="w-4 h-4 text-emerald-400" />
              <span>{msg}</span>
            </div>
          )}
        </div>
      </div>

      {/* Add Alias Input Box */}
      <div className="p-4 rounded-2xl bg-white/5 border border-white/10 space-y-3">
        <h3 className="text-xs font-semibold text-gray-300">Create New Shell Shortcut</h3>
        <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
          <input
            type="text"
            value={aliasName}
            onChange={(e) => setAliasName(e.target.value)}
            placeholder="Shortcut Name (e.g. g)"
            className="px-3 py-2 text-xs rounded-xl bg-black/40 border border-white/10 text-white focus:outline-none focus:ring-1 focus:ring-blue-500"
          />

          <input
            type="text"
            value={aliasCommand}
            onChange={(e) => setAliasCommand(e.target.value)}
            placeholder="Target Command (e.g. git)"
            className="px-3 py-2 text-xs rounded-xl bg-black/40 border border-white/10 text-white focus:outline-none focus:ring-1 focus:ring-blue-500"
          />

          <button
            onClick={handleAddAlias}
            disabled={loading}
            className="px-4 py-2 rounded-xl bg-blue-600 hover:bg-blue-500 text-white text-xs font-semibold flex items-center justify-center space-x-1.5 shadow-md"
          >
            <Plus className="w-4 h-4" />
            <span>Register Alias</span>
          </button>
        </div>
      </div>

      {/* Alias Table */}
      <div className="rounded-2xl border border-fluent-border-dark bg-fluent-bg-dark/50 overflow-hidden shadow-mica">
        <table className="w-full text-left text-xs">
          <thead className="bg-white/5 border-b border-fluent-border-dark text-gray-400 font-semibold uppercase text-[10px]">
            <tr>
              <th className="p-4">Shortcut Name</th>
              <th className="p-4">Target Command</th>
              <th className="p-4">Target File</th>
              <th className="p-4 text-right">Actions</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-fluent-border-dark text-gray-200">
            {loading ? (
              <tr>
                <td colSpan={4} className="p-8 text-center text-xs text-gray-400 font-mono">
                  <RefreshCw className="w-5 h-5 animate-spin mx-auto mb-2 text-blue-400" />
                  Reading PowerShell profile ($PROFILE)...
                </td>
              </tr>
            ) : aliases.length === 0 ? (
              <tr>
                <td colSpan={4} className="p-8 text-center text-xs text-gray-400">
                  No custom aliases registered in $PROFILE yet.
                </td>
              </tr>
            ) : (
              aliases.map((a) => (
                <tr key={a.id} className="hover:bg-white/5">
                  <td className="p-4 font-mono font-bold text-blue-400">{a.name}</td>
                  <td className="p-4 font-mono text-gray-300">{a.command}</td>
                  <td className="p-4 text-gray-400 font-mono text-[10px]">{a.profilePath}</td>
                  <td className="p-4 text-right">
                    <button
                      onClick={() => handleRemoveAlias(a.name)}
                      className="p-1.5 rounded-lg text-red-400 hover:bg-red-500/20"
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
  );
};
