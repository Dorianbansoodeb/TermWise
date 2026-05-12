// Theme tokens. Two palettes (light + dark) and a single `useTheme` hook drives
// every screen — matches the light/dark feel of the SwiftUI app.

export interface ThemePalette {
  scheme: 'light' | 'dark';
  background: string;
  surface: string;
  surfaceMuted: string;
  card: string;
  border: string;
  text: string;
  textMuted: string;
  textInverse: string;
  primary: string;
  primaryText: string;
  accent: string;
  positive: string;
  warning: string;
  danger: string;
  chartGrid: string;
  chartActual: string;
  chartPace: string;
  chartProjection: string;
  chartLimit: string;
}

export const LIGHT_PALETTE: ThemePalette = {
  scheme: 'light',
  background: '#f8fafc',
  surface: '#ffffff',
  surfaceMuted: '#f1f5f9',
  card: '#ffffff',
  border: '#e2e8f0',
  text: '#0f172a',
  textMuted: '#64748b',
  textInverse: '#ffffff',
  primary: '#f97316',
  primaryText: '#ffffff',
  accent: '#3b82f6',
  positive: '#22c55e',
  warning: '#f59e0b',
  danger: '#ef4444',
  chartGrid: '#e2e8f0',
  chartActual: '#3b82f6',
  chartPace: '#f97316',
  chartProjection: '#ef4444',
  chartLimit: '#94a3b8'
};

export const DARK_PALETTE: ThemePalette = {
  scheme: 'dark',
  background: '#0b1220',
  surface: '#111827',
  surfaceMuted: '#1f2937',
  card: '#111827',
  border: '#1f2937',
  text: '#f8fafc',
  textMuted: '#94a3b8',
  textInverse: '#0b1220',
  primary: '#fb923c',
  primaryText: '#0b1220',
  accent: '#60a5fa',
  positive: '#4ade80',
  warning: '#fbbf24',
  danger: '#f87171',
  chartGrid: '#1f2937',
  chartActual: '#60a5fa',
  chartPace: '#fb923c',
  chartProjection: '#f87171',
  chartLimit: '#475569'
};

export const SPACING = {
  xs: 4,
  sm: 8,
  md: 12,
  lg: 16,
  xl: 24,
  xxl: 32
} as const;

export const RADIUS = {
  sm: 8,
  md: 12,
  lg: 16,
  xl: 20,
  pill: 999
} as const;
