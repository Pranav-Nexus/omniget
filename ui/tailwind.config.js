/** @type {import('tailwindcss').Config} */
export default {
  darkMode: 'class',
  content: [
    './index.html',
    './src/**/*.{js,ts,jsx,tsx}',
  ],
  theme: {
    extend: {
      colors: {
        fluent: {
          bg: {
            dark: '#1c1c1c',
            light: '#f3f3f3',
            cardDark: '#262626',
            cardLight: '#ffffff',
            hoverDark: '#323232',
            hoverLight: '#eaeaea',
          },
          border: {
            dark: 'rgba(255, 255, 255, 0.08)',
            light: 'rgba(0, 0, 0, 0.08)',
          },
          winget: '#0078D4',
          choco: '#805030',
          scoop: '#107C41',
          pip: '#3776AB',
          npm: '#CB3837',
          cargo: '#DEA584',
          accent: 'var(--system-accent-color, #005FB8)',
        },
      },
      fontFamily: {
        sans: ['"Segoe UI Variable"', '"Segoe UI"', 'Inter', 'sans-serif'],
        mono: ['"Cascadia Code"', '"Consolas"', 'monospace'],
      },
      boxShadow: {
        fluent: '0 4px 16px rgba(0, 0, 0, 0.25)',
        fluentLight: '0 4px 16px rgba(0, 0, 0, 0.06)',
        mica: '0 8px 32px 0 rgba(0, 0, 0, 0.37)',
      },
      backdropBlur: {
        mica: '20px',
      },
    },
  },
  plugins: [],
};
