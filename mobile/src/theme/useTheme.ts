import { useColorScheme } from 'react-native';
import { useAppState } from '../state/AppState';
import { DARK_PALETTE, LIGHT_PALETTE, type ThemePalette } from './tokens';

export function useTheme(): ThemePalette {
  const systemScheme = useColorScheme();
  const { appUserSettings } = useAppState();
  const pref = appUserSettings.themePreference;
  const effectiveScheme: 'light' | 'dark' =
    pref === 'light' ? 'light' : pref === 'dark' ? 'dark' : systemScheme === 'dark' ? 'dark' : 'light';
  return effectiveScheme === 'dark' ? DARK_PALETTE : LIGHT_PALETTE;
}
