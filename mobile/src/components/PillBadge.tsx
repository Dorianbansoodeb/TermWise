import React from 'react';
import { StyleSheet, Text, View, type ViewStyle } from 'react-native';
import { RADIUS, SPACING } from '../theme/tokens';

interface PillBadgeProps {
  label: string;
  tone?: 'neutral' | 'positive' | 'warning' | 'danger';
  style?: ViewStyle;
}

const TONE_BG: Record<NonNullable<PillBadgeProps['tone']>, string> = {
  neutral: '#e2e8f0',
  positive: '#dcfce7',
  warning: '#fef3c7',
  danger: '#fee2e2'
};

const TONE_FG: Record<NonNullable<PillBadgeProps['tone']>, string> = {
  neutral: '#0f172a',
  positive: '#166534',
  warning: '#92400e',
  danger: '#991b1b'
};

export function PillBadge({ label, tone = 'neutral', style }: PillBadgeProps) {
  return (
    <View style={[styles.container, { backgroundColor: TONE_BG[tone] }, style]}>
      <Text style={[styles.label, { color: TONE_FG[tone] }]}>{label}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    borderRadius: RADIUS.pill,
    paddingVertical: 4,
    paddingHorizontal: SPACING.sm
  },
  label: {
    fontSize: 12,
    fontWeight: '600'
  }
});
