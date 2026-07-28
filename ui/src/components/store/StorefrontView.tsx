import React, { useState } from 'react';
import { Package, CliFlags } from '../../types/omniget';
import { HeroCarousel } from './HeroCarousel';
import { AppCard } from './AppCard';
import { FEATURED_APPS, CATALOG_APPS, CliBridge } from '../../services/cliBridge';

interface StorefrontViewProps {
  onInstallPackage: (pkg: Package, flags?: CliFlags) => void;
  onSelectPackage: (pkg: Package) => void;
  installedIds?: string[];
}

export const StorefrontView: React.FC<StorefrontViewProps> = ({
  onInstallPackage,
  onSelectPackage,
}) => {
  const [selectedCategory, setSelectedCategory] = useState<string>('All');

  const categories = ['All', 'Development', 'Utilities', 'Browsers', 'Media', 'Productivity'];

  const filteredApps = selectedCategory === 'All'
    ? CATALOG_APPS
    : CATALOG_APPS.filter(app => app.category === selectedCategory);

  return (
    <div className="p-6 md:p-8 space-y-8 overflow-y-auto h-full">
      {/* Header Banner */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 border-b border-slate-200 dark:border-fluent-border-dark pb-6">
        <div>
          <h1 className="text-2xl font-extrabold text-slate-900 dark:text-white tracking-tight flex items-center space-x-2">
            <span>OmniGet Package Hub</span>
          </h1>
          <p className="text-xs text-slate-600 dark:text-gray-400 mt-1">
            Explore and install top open-source tools powered concurrently by WinGet, Chocolatey, and Scoop.
          </p>
        </div>
      </div>

      {/* Hero Featured Carousel */}
      <HeroCarousel 
        apps={FEATURED_APPS} 
        onInstall={onInstallPackage}
        onSelectApp={onSelectPackage} 
      />

      {/* Category Pills & Catalog Grid */}
      <div className="space-y-4">
        <div className="flex items-center justify-between">
          <div className="flex items-center space-x-2 overflow-x-auto py-1">
            {categories.map((cat) => (
              <button
                key={cat}
                onClick={() => setSelectedCategory(cat)}
                className={`px-4 py-1.5 rounded-full text-xs font-semibold transition-all ${
                  selectedCategory === cat
                    ? 'bg-blue-600 text-white shadow-md shadow-blue-600/30'
                    : 'bg-slate-100 dark:bg-white/5 text-slate-600 dark:text-gray-400 hover:text-slate-900 dark:hover:text-white hover:bg-slate-200 dark:hover:bg-white/10'
                }`}
              >
                {cat}
              </button>
            ))}
          </div>

          <div className="text-xs text-slate-500 dark:text-gray-400 font-mono">
            {filteredApps.length} Packages
          </div>
        </div>

        {/* App Cards Grid */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-5">
          {filteredApps.map((pkg) => (
            <AppCard
              key={pkg.id}
              app={pkg}
              onInstall={onInstallPackage}
              onSelectApp={onSelectPackage}
            />
          ))}
        </div>
      </div>
    </div>
  );
};
