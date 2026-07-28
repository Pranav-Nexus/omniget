import React, { useState, useEffect } from 'react';
import { Download, ChevronLeft, ChevronRight, Star, ExternalLink, ShieldCheck } from 'lucide-react';
import { Package, CliFlags } from '../../types/omniget';

interface HeroCarouselProps {
  apps: Package[];
  onInstall: (pkg: Package, flags?: CliFlags) => void;
  onSelectApp: (pkg: Package) => void;
}

export const HeroCarousel: React.FC<HeroCarouselProps> = ({ apps, onInstall, onSelectApp }) => {
  const [currentIndex, setCurrentIndex] = useState(0);

  useEffect(() => {
    const timer = setInterval(() => {
      setCurrentIndex((prev) => (prev + 1) % apps.length);
    }, 6000);
    return () => clearInterval(timer);
  }, [apps.length]);

  if (!apps || apps.length === 0) return null;
  const currentApp = apps[currentIndex];

  return (
    <div className="relative rounded-2xl overflow-hidden bg-gradient-to-r from-slate-900 via-indigo-950 to-blue-900 border border-blue-500/30 p-6 md:p-8 shadow-xl mb-8 group text-white">
      {/* Background Accent Glow */}
      <div className="absolute -top-24 -right-24 w-96 h-96 bg-blue-500/20 rounded-full blur-3xl pointer-events-none" />

      <div className="relative z-10 flex flex-col md:flex-row items-start md:items-center justify-between gap-6">
        <div className="max-w-xl space-y-3">
          <div className="flex items-center space-x-2">
            <span className="px-2.5 py-0.5 rounded-full text-[10px] font-bold bg-blue-500 text-white uppercase tracking-wider shadow-sm">
              Featured Choice
            </span>
            <span className="flex items-center text-xs text-amber-400 font-semibold space-x-1">
              <Star className="w-3.5 h-3.5 fill-amber-400" />
              <span>{currentApp.rating}</span>
            </span>
            <span className="text-xs text-blue-200/80">• {currentApp.downloads} Downloads</span>
          </div>

          <h2 className="text-2xl md:text-3xl font-bold text-white tracking-tight">
            {currentApp.name}
          </h2>

          <p className="text-xs md:text-sm text-slate-200 leading-relaxed line-clamp-2">
            {currentApp.description}
          </p>

          <div className="flex items-center space-x-3 pt-2">
            <button
              onClick={() => onInstall(currentApp)}
              className="px-5 py-2.5 rounded-xl bg-blue-600 hover:bg-blue-500 text-white font-semibold text-xs flex items-center space-x-2 shadow-lg shadow-blue-600/40 transition-all hover:scale-105 active:scale-95"
            >
              <Download className="w-4 h-4" />
              <span>Install Latest ({currentApp.version})</span>
            </button>

            <button
              onClick={() => onSelectApp(currentApp)}
              className="px-4 py-2.5 rounded-xl bg-white/10 hover:bg-white/20 text-white font-medium text-xs border border-white/20 transition-all flex items-center space-x-1.5 backdrop-blur-sm"
            >
              <span>View Details</span>
              <ExternalLink className="w-3.5 h-3.5 text-slate-300" />
            </button>
          </div>
        </div>

        {/* Source Badges & Info */}
        <div className="flex flex-col items-start md:items-end space-y-3">
          <div className="flex items-center space-x-2">
            <span className="text-xs text-slate-300 font-medium">Available Sources:</span>
            {currentApp.sourcesAvailable?.map((src) => (
              <span
                key={src}
                className={`px-2.5 py-1 rounded text-[10px] font-mono uppercase font-bold border ${
                  src === 'winget' ? 'bg-blue-500/20 text-blue-300 border-blue-400/40' :
                  src === 'choco' ? 'bg-amber-500/20 text-amber-300 border-amber-400/40' :
                  'bg-emerald-500/20 text-emerald-300 border-emerald-400/40'
                }`}
              >
                {src}
              </span>
            ))}
          </div>

          <div className="text-xs text-slate-300 flex items-center space-x-1 font-medium">
            <ShieldCheck className="w-4 h-4 text-emerald-400" />
            <span>Verified Publisher • {currentApp.publisher}</span>
          </div>
        </div>
      </div>

      {/* Navigation Arrows & Indicators */}
      <button
        onClick={() => setCurrentIndex((prev) => (prev - 1 + apps.length) % apps.length)}
        className="absolute left-2 top-1/2 -translate-y-1/2 p-2 rounded-full bg-black/40 hover:bg-black/60 text-white opacity-0 group-hover:opacity-100 transition-opacity"
      >
        <ChevronLeft className="w-5 h-5" />
      </button>

      <button
        onClick={() => setCurrentIndex((prev) => (prev + 1) % apps.length)}
        className="absolute right-2 top-1/2 -translate-y-1/2 p-2 rounded-full bg-black/40 hover:bg-black/60 text-white opacity-0 group-hover:opacity-100 transition-opacity"
      >
        <ChevronRight className="w-5 h-5" />
      </button>

      <div className="absolute bottom-3 left-1/2 -translate-x-1/2 flex items-center space-x-1.5">
        {apps.map((_, idx) => (
          <button
            key={idx}
            onClick={() => setCurrentIndex(idx)}
            className={`h-1.5 rounded-full transition-all ${
              idx === currentIndex ? 'w-6 bg-blue-400' : 'w-1.5 bg-white/40'
            }`}
          />
        ))}
      </div>
    </div>
  );
};
