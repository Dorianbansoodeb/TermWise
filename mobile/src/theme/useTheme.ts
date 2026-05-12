import { useColorScheme } from 'react-native';
import { DARK_PALETTE, LIGHT_PALETTE, type ThemePalette } from './tokens';

export function useTheme(): ThemePalette {
  const scheme = useColorScheme();
  return scheme === 'dark' ? DARK_PALETTE : LIGHT_PALETTE;
}
