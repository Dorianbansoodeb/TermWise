import React from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import type { ChartRange } from '../types/models';
import { rangeShortLabel, VARIABLE_PICKER_RANGES } from '../utils/chartCalculator';
import { useTheme } from '../theme/useTheme';
import { RADIUS, SPACING } from '../theme/tokens';

interface SpendTrendRangePickerProps {
  value: ChartRange;
  onChange: (next: ChartRange) => void;
}

export function SpendTrendRangePicker({ value, onChange }: SpendTrendRangePickerProps) {
  const theme = useTheme();
  return (
    <View style={[styles.container, { backgroundColor: theme.surfaceMuted }]}>
      {VARIABLE_PICKER_RANGES.map((range) => {
        const selected = range === value;
        return (
          <Pressable
            key={range}
            onPress={() => onChange(range)}
            style={[
              styles.segment,
              selected && { backgroundColor: theme.surface, borderColor: theme.border }
            ]}
          >
            <Text
              style={[
                styles.label,
                {
                  color: selected ? theme.text : theme.textMuted,
                  fontWeight: selected ? '700' : '500'
                }
              ]}
            >
              {rangeShortLabel(range)}
            </Text>
          </Pressable>
        );
      })}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flexDirection: 'row',
    padding: 3,
    borderRadius: RADIUS.pill,
    gap: 2
  },
  segment: {
    flex: 1,
    paddingVertical: SPACING.xs + 2,
    paddingHorizontal: SPACING.sm,
    borderRadius: RADIUS.pill,
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: 'transparent'
  },
  label: {
    fontSize: 12
  }
});
