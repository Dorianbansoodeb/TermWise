import React from 'react';
import { Pressable, StyleSheet, Text, type ViewStyle } from 'react-native';
import { useTheme } from '../theme/useTheme';
import { RADIUS, SPACING } from '../theme/tokens';

interface PrimaryButtonProps {
  title: string;
  onPress: () => void;
  variant?: 'primary' | 'secondary' | 'ghost' | 'danger';
  disabled?: boolean;
  style?: ViewStyle;
}

export function PrimaryButton({
  title,
  onPress,
  variant = 'primary',
  disabled,
  style
}: PrimaryButtonProps) {
  const theme = useTheme();
  const palette = {
    primary: { bg: theme.primary, text: theme.primaryText, border: theme.primary },
    secondary: { bg: theme.surfaceMuted, text: theme.text, border: theme.border },
    ghost: { bg: 'transparent', text: theme.text, border: theme.border },
    danger: { bg: theme.danger, text: '#ffffff', border: theme.danger }
  }[variant];

  return (
    <Pressable
      onPress={onPress}
      disabled={disabled}
      accessibilityRole="button"
      style={({ pressed }) => [
        styles.button,
        {
          backgroundColor: palette.bg,
          borderColor: palette.border,
          opacity: disabled ? 0.5 : pressed ? 0.85 : 1
        },
        style
      ]}
    >
      <Text style={[styles.label, { color: palette.text }]}>{title}</Text>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  button: {
    paddingVertical: SPACING.md,
    paddingHorizontal: SPACING.lg,
    borderRadius: RADIUS.md,
    borderWidth: 1,
    alignItems: 'center',
    justifyContent: 'center'
  },
  label: {
    fontSize: 15,
    fontWeight: '600'
  }
});
