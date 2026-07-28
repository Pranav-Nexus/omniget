import React, { createContext, useContext, useEffect, useState } from 'react';

type ThemeMode = 'system' | 'dark' | 'light';

interface ThemeContextType {
  theme: ThemeMode;
  setTheme: (theme: ThemeMode) => void;
  isDark: boolean;
  accentColor: string;
  setAccentColor: (color: string) => void;
}

const ThemeContext = createContext<ThemeContextType | undefined>(undefined);

export const ThemeProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [theme, setThemeState] = useState<ThemeMode>(() => {
    const saved = localStorage.getItem('omniget_theme');
    if (saved === 'dark' || saved === 'light' || saved === 'system') {
      return saved as ThemeMode;
    }
    return 'system';
  });

  const [isDark, setIsDark] = useState<boolean>(true);

  const [accentColor, setAccentColorState] = useState<string>(() => {
    return localStorage.getItem('omniget_accent_color') || '#005FB8';
  });

  const setTheme = (newTheme: ThemeMode) => {
    setThemeState(newTheme);
    localStorage.setItem('omniget_theme', newTheme);
  };

  const setAccentColor = (color: string) => {
    setAccentColorState(color);
    localStorage.setItem('omniget_accent_color', color);
    document.documentElement.style.setProperty('--system-accent-color', color);
  };

  useEffect(() => {
    // Initial accent color sync
    document.documentElement.style.setProperty('--system-accent-color', accentColor);
  }, [accentColor]);

  useEffect(() => {
    const mediaQuery = window.matchMedia('(prefers-color-scheme: dark)');

    const updateTheme = () => {
      let activeDark = true;
      if (theme === 'system') {
        activeDark = mediaQuery.matches;
      } else {
        activeDark = theme === 'dark';
      }
      setIsDark(activeDark);

      if (activeDark) {
        document.documentElement.classList.add('dark');
        document.documentElement.classList.remove('light');
      } else {
        document.documentElement.classList.remove('dark');
        document.documentElement.classList.add('light');
      }
    };

    updateTheme();
    mediaQuery.addEventListener('change', updateTheme);
    return () => mediaQuery.removeEventListener('change', updateTheme);
  }, [theme]);

  return (
    <ThemeContext.Provider value={{ theme, setTheme, isDark, accentColor, setAccentColor }}>
      {children}
    </ThemeContext.Provider>
  );
};

export const useTheme = () => {
  const context = useContext(ThemeContext);
  if (!context) {
    throw new Error('useTheme must be used within a ThemeProvider');
  }
  return context;
};
