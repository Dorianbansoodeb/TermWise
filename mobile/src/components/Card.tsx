import React from 'react';
import { StyleSheet, View, type ViewProps, type ViewStyle } from 'react-native';
import { useTheme } from '../theme/useTheme';
import { RADIUS, SPACING } from '../theme/tokens';

export function Card({ style, children, ...rest }: ViewProps) {
  const theme = useTheme();
  const dynamic: ViewStyle = {
    backgroundColor: theme.card,
    borderColor: theme.border
  };
  return (
    <View {...rest} style={[styles.card, dynamic, style]}>
      {children}
    </View>
  );
}

const styles = StyleSheet.create({
  card: {
    borderRadius: RADIUS.lg,
    padding: SPACING.lg,
    borderWidth: StyleSheet.hairlineWidth
  }
});
