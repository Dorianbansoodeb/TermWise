import React, { useState } from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { Card } from './Card';
import { useAppState } from '../state/AppState';
import { useTheme } from '../theme/useTheme';
import { RADIUS, SPACING } from '../theme/tokens';
import type { SpendingBreakdown } from '../utils/financeCalculator';

interface PlanVsRealityBarProps {
  breakdown: SpendingBreakdown;
}

/// Segmented spending breakdown. Mirrors the iOS "Plan vs Reality" bar:
/// segments scale by share of `availableToBudget`, an "Over budget" red flag
/// shows when total exceeds available, tap to expand the legend.
export function PlanVsRealityBar({ breakdown }: PlanVsRealityBarProps) {
  const theme = useTheme();
  const { formatMoney } = useAppState();
  const [expanded, setExpanded] = useState(false);

  const overBy = breakdown.overBudgetByAmount;
  const segmentsAllZero =
    breakdown.segments.length === 0 ||
    breakdown.segments.every((seg) => seg.amount === 0);

  return (
    <Card
      style={[
        breakdown.isOver && { borderColor: theme.danger, borderWidth: 1 }
      ]}
    >
      <Pressable onPress={() => setExpanded((p) => !p)}>
        <View style={styles.header}>
          <Text style={[styles.title, { color: theme.text }]}>Plan vs Reality</Text>
          <Text style={[styles.subtitle, { color: theme.textMuted }]}>
            Actual {formatMoney(breakdown.actualTotal, { compact: true })} / Available {formatMoney(breakdown.availableToBudget, { compact: true })}
          </Text>
        </View>

        <View style={[styles.barTrack, { backgroundColor: theme.surfaceMuted }]}>
          {breakdown.segments.map((seg) => {
            const widthPct = Math.max(2, Math.min(100, seg.fractionOfAvailable * 100));
            return (
              <View
                key={seg.category}
                style={{
                  width: `${widthPct}%`,
                  backgroundColor: seg.color,
                  height: '100%'
                }}
              />
            );
          })}
        </View>

        {breakdown.isOver && (
          <Text style={[styles.overText, { color: theme.danger }]}>
            Over budget by {formatMoney(overBy, { compact: true })}
          </Text>
        )}

        {segmentsAllZero && (
          <Text style={[styles.hintText, { color: theme.textMuted }]}>
            No expense transactions yet this month.
          </Text>
        )}

        {expanded && breakdown.segments.length > 0 && (
          <View style={styles.legend}>
            {breakdown.segments.map((seg) => (
              <View key={seg.category} style={styles.legendRow}>
                <View style={[styles.swatch, { backgroundColor: seg.color }]} />
                <Text style={[styles.legendLabel, { color: theme.text }]} numberOfLines={1}>
                  {seg.category}
                </Text>
                <Text style={[styles.legendValue, { color: theme.textMuted }]}>
                  {formatMoney(seg.amount, { compact: true })}
                </Text>
              </View>
            ))}
          </View>
        )}
      </Pressable>
    </Card>
  );
}

const styles = StyleSheet.create({
  header: {
    marginBottom: SPACING.sm
  },
  title: {
    fontSize: 14,
    fontWeight: '700'
  },
  subtitle: {
    fontSize: 12,
    marginTop: 2
  },
  barTrack: {
    flexDirection: 'row',
    height: 14,
    borderRadius: RADIUS.pill,
    overflow: 'hidden'
  },
  overText: {
    marginTop: SPACING.sm,
    fontSize: 12,
    fontWeight: '600'
  },
  hintText: {
    marginTop: SPACING.sm,
    fontSize: 12
  },
  legend: {
    marginTop: SPACING.sm,
    gap: 4
  },
  legendRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: SPACING.sm
  },
  swatch: {
    width: 10,
    height: 10,
    borderRadius: 5
  },
  legendLabel: {
    flex: 1,
    fontSize: 12
  },
  legendValue: {
    fontSize: 12,
    fontWeight: '600'
  }
});
