import React from 'react';
import { Terminal as TerminalIcon, Copy, Trash2, X } from 'lucide-react';
import { TerminalLog } from '../../types/omniget';

interface TerminalDrawerProps {
  isOpen: boolean;
  onClose: () => void;
  logs: TerminalLog[];
  onClearLogs: () => void;
}

export const TerminalDrawer: React.FC<TerminalDrawerProps> = ({
  isOpen,
  onClose,
  logs,
  onClearLogs
}) => {
  if (!isOpen) return null;

  const handleCopyLogs = () => {
    const text = logs.map(l => `[${l.timestamp}] ${l.text}`).join('\n');
    navigator.clipboard.writeText(text);
  };

  return (
    <div className="h-64 border-t border-slate-300 dark:border-fluent-border-dark bg-slate-100 dark:bg-[#0f0f10] text-slate-900 dark:text-gray-100 flex flex-col font-mono text-xs z-30 transition-colors duration-200 shadow-lg">
      {/* Header Bar */}
      <div className="h-8 px-4 bg-slate-200 dark:bg-fluent-bg-dark border-b border-slate-300 dark:border-fluent-border-dark flex items-center justify-between text-[11px] select-none">
        <div className="flex items-center space-x-2 font-bold text-slate-800 dark:text-white">
          <TerminalIcon className="w-3.5 h-3.5 text-blue-600 dark:text-blue-400" />
          <span>OmniGet Execution Terminal (stdout)</span>
        </div>

        <div className="flex items-center space-x-3 text-slate-600 dark:text-gray-400">
          <button
            onClick={handleCopyLogs}
            className="hover:text-slate-900 dark:hover:text-white flex items-center space-x-1 py-0.5 px-1.5 rounded hover:bg-slate-300 dark:hover:bg-white/10 transition-colors"
            title="Copy Logs"
          >
            <Copy className="w-3 h-3" />
            <span>Copy</span>
          </button>
          <button
            onClick={onClearLogs}
            className="hover:text-slate-900 dark:hover:text-white flex items-center space-x-1 py-0.5 px-1.5 rounded hover:bg-slate-300 dark:hover:bg-white/10 transition-colors"
            title="Clear Terminal"
          >
            <Trash2 className="w-3 h-3" />
            <span>Clear</span>
          </button>
          <button
            onClick={onClose}
            className="hover:text-slate-900 dark:hover:text-white p-0.5 rounded hover:bg-slate-300 dark:hover:bg-white/10 transition-colors"
          >
            <X className="w-3.5 h-3.5" />
          </button>
        </div>
      </div>

      {/* Output Console Log Area */}
      <div className="flex-1 p-3 overflow-y-auto space-y-1 bg-white dark:bg-[#121212] select-text">
        {logs.length === 0 ? (
          <div className="text-slate-400 dark:text-gray-500 italic text-[11px] p-2 text-center">
            Terminal ready. Executed CLI operations will stream output here in real-time...
          </div>
        ) : (
          logs.map((log) => (
            <div key={log.id} className="flex items-start space-x-2 text-[11px] leading-relaxed">
              <span className="text-slate-400 dark:text-gray-500 select-none">[{log.timestamp}]</span>
              <span
                className={
                  log.level === 'error'
                    ? 'text-red-600 dark:text-red-400 font-bold'
                    : log.level === 'warn'
                    ? 'text-amber-600 dark:text-amber-400'
                    : log.level === 'success'
                    ? 'text-emerald-700 dark:text-emerald-400 font-semibold'
                    : 'text-blue-700 dark:text-blue-300'
                }
              >
                {log.text}
              </span>
            </div>
          ))
        )}
      </div>
    </div>
  );
};
