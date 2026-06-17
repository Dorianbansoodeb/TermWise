import React, { useMemo, useState } from 'react';
import {
  KeyboardAvoidingView,
  Modal,
  Platform,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  View
} from 'react-native';
import type { BudgetItem } from '../types/models';
import { useAppState } from '../state/AppState';
import { useTheme } from '../theme/useTheme';
import { RADIUS, SPACING, type ThemePalette } from '../theme/tokens';
import { monthYearLabel, parseMonthKey } from '../utils/date';
import {
  budgetPercentUsed,
  profileExpenseBreakdownRows,
  type ProfileMonthSummary
} from '../utils/financeCalculator';
import { Card } from './Card';

const TRACK_H = 56;
const BAR_W = 14;

type Props = {
  summaries: ProfileMonthSummary[];
  budgetItems: BudgetItem[];
  monthlyNotes: Record<string, string>;
  onSetNoteForMonth: (monthKey: string, note: string) => void;
};

export function ProfilePastMonthsCard({
  summaries,
  budgetItems,
  monthlyNotes,
  onSetNoteForMonth
}: Props) {
  const theme = useTheme();
  const { formatMoney } = useAppState();
  const [selected, setSelected] = useState<ProfileMonthSummary | null>(null);

  const maxPercent = useMemo(() => {
    let m = 100;
    for (const s of summaries) {
      m = Math.max(m, budgetPercentUsed(s.actual, s.planned));
    }
    return m;
  }, [summaries]);

  const breakdown = useMemo(() => {
    if (!selected) return [];
    return profileExpenseBreakdownRows(budgetItems, selected.planned, selected.actual);
  }, [budgetItems, selected]);

  const pctUsed = selected ? budgetPercentUsed(selected.actual, selected.planned) : 0;
  const overBy = selected && selected.actual > selected.planned ? selected.actual - selected.planned : 0;
  const underBy = selected && selected.actual <= selected.planned ? selected.planned - selected.actual : 0;

  return (
    <>
      <Card>
        <Text style={[styles.section, { color: theme.text }]}>Past months</Text>
        <Text style={[styles.subtitle, { color: theme.textMuted }]}>
          Past category breakdown is estimated from your current plan.
        </Text>
        <Text style={[styles.helper, { color: theme.textMuted }]}>
          Tap a month for planned vs actual, a category-style breakdown, and the note you saved for
          that month.
        </Text>
        <View style={styles.chartRow}>
          {summaries.map((s) => {
            const rawPct = budgetPercentUsed(s.actual, s.planned);
            const displayPct = Math.min(999, Math.round(rawPct));
            const fillRatio = Math.min(1, rawPct / maxPercent);
            const fillH = Math.max(4, Math.round(TRACK_H * fillRatio));
            const barColor = s.actual > s.planned ? theme.danger : theme.positive;
            return (
              <Pressable
                key={s.monthKey}
                accessibilityRole="button"
                accessibilityLabel={`${s.monthLabel}, ${displayPct} percent of budget used`}
                onPress={() => setSelected(s)}
                style={styles.col}
              >
                <Text style={[styles.pct, { color: theme.text }]}>{displayPct}%</Text>
                <View
                  style={[
                    styles.track,
                    { height: TRACK_H, backgroundColor: theme.surfaceMuted, borderColor: theme.border }
                  ]}
                >
                  <View style={[styles.fill, { height: fillH, backgroundColor: barColor, width: BAR_W }]} />
                </View>
                <Text style={[styles.monthLbl, { color: theme.textMuted }]}>{s.monthLabel}</Text>
              </Pressable>
            );
          })}
        </View>
      </Card>

      <Modal
        visible={!!selected}
        animationType="slide"
        transparent
        onRequestClose={() => setSelected(null)}
      >
        <KeyboardAvoidingView
          style={styles.modalRoot}
          behavior={Platform.OS === 'ios' ? 'padding' : undefined}
        >
          <View style={[styles.modalBackdrop, { backgroundColor: 'rgba(0,0,0,0.45)' }]}>
            <Pressable style={styles.modalTapDismiss} onPress={() => setSelected(null)} />
            <View
              style={[
                styles.sheet,
                {
                  backgroundColor: theme.card,
                  borderColor: theme.border
                }
              ]}
            >
              {selected ? (
                <>
                  <View style={styles.sheetHeader}>
                    <Text style={[styles.sheetTitle, { color: theme.text }]}>
                      {monthYearLabel(parseMonthKey(selected.monthKey))}
                    </Text>
                    <Pressable onPress={() => setSelected(null)} hitSlop={12}>
                      <Text style={[styles.close, { color: theme.primary }]}>Done</Text>
                    </Pressable>
                  </View>
                  <ScrollView
                    keyboardShouldPersistTaps="handled"
                    showsVerticalScrollIndicator={false}
                    contentContainerStyle={styles.sheetScroll}
                  >
                    <Text style={[styles.metricLine, { color: theme.textMuted }]}>
                      Budget used{' '}
                      <Text style={{ color: theme.text, fontWeight: '700' }}>
                        {Math.round(pctUsed)}%
                      </Text>
                    </Text>
                    <MetricRow label="Planned" value={selected.planned} theme={theme} accent={theme.textMuted} />
                    <MetricRow label="Actual" value={selected.actual} theme={theme} accent={theme.chartActual} />
                    <MetricRow
                      label="Saved (planned − actual)"
                      value={selected.saved}
                      theme={theme}
                      accent={selected.saved >= 0 ? theme.positive : theme.danger}
                    />
                    <Text style={[styles.body, { color: theme.text }]}>
                      {overBy > 0
                        ? `You spent ${formatMoney(overBy, { compact: true })} more than planned this month.`
                        : underBy > 0
                          ? `You came in ${formatMoney(underBy, { compact: true })} under planned spend.`
                          : 'Spending matched your plan for the month.'}
                    </Text>

                    <Text style={[styles.subhead, { color: theme.text }]}>Expense breakdown</Text>
                    <Text style={[styles.micro, { color: theme.textMuted }]}>
                      Expected split follows your current budget mix; actuals scale with that month’s
                      total spend (Swift-style estimate).
                    </Text>
                    {breakdown.map((row) => (
                      <View key={row.category} style={styles.breakRow}>
                        <Text style={[styles.cat, { color: theme.text }]} numberOfLines={1}>
                          {row.category}
                        </Text>
                        <Text style={[styles.brVal, { color: theme.textMuted }]}>
                          {formatMoney(row.actual, { compact: true })} /{' '}
                          {formatMoney(row.expected, { compact: true })}
                        </Text>
                      </View>
                    ))}

                    <Text style={[styles.subhead, { color: theme.text, marginTop: SPACING.md }]}>
                      Monthly note
                    </Text>
                    <TextInput
                      multiline
                      value={monthlyNotes[selected.monthKey] ?? ''}
                      onChangeText={(t) => onSetNoteForMonth(selected.monthKey, t)}
                      style={[
                        styles.textArea,
                        {
                          color: theme.text,
                          borderColor: theme.border,
                          backgroundColor: theme.surface
                        }
                      ]}
                      placeholder="Note for this month…"
                      placeholderTextColor={theme.textMuted}
                    />
                  </ScrollView>
                </>
              ) : null}
            </View>
          </View>
        </KeyboardAvoidingView>
      </Modal>
    </>
  );
}

function MetricRow({
  label,
  value,
  theme,
  accent
}: {
  label: string;
  value: number;
  theme: ThemePalette;
  accent: string;
}) {
  const { formatMoney } = useAppState();
  return (
    <View style={styles.metricRow}>
      <View style={[styles.metricDot, { backgroundColor: accent }]} />
      <Text style={[styles.metricLabel, { color: theme.text }]}>{label}</Text>
      <Text style={[styles.metricValue, { color: theme.text }]}>{formatMoney(value)}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  section: {
    fontSize: 16,
    fontWeight: '700'
  },
  subtitle: {
    fontSize: 12,
    marginTop: 2
  },
  helper: {
    fontSize: 12,
    marginTop: 2,
    marginBottom: SPACING.md
  },
  chartRow: {
    flexDirection: 'row',
    alignItems: 'flex-end',
    justifyContent: 'space-between',
    gap: 4,
    minHeight: TRACK_H + 52
  },
  col: {
    flex: 1,
    alignItems: 'center',
    minWidth: 0
  },
  pct: {
    fontSize: 11,
    fontWeight: '700',
    marginBottom: 4
  },
  track: {
    width: BAR_W + 6,
    borderRadius: RADIUS.md,
    borderWidth: StyleSheet.hairlineWidth,
    alignItems: 'center',
    justifyContent: 'flex-end',
    overflow: 'hidden',
    paddingBottom: 2
  },
  fill: {
    borderRadius: RADIUS.sm
  },
  monthLbl: {
    fontSize: 10,
    fontWeight: '600',
    marginTop: 6
  },
  modalRoot: {
    flex: 1
  },
  modalBackdrop: {
    flex: 1,
    justifyContent: 'flex-end'
  },
  modalTapDismiss: {
    flex: 1,
    width: '100%'
  },
  sheet: {
    maxHeight: '88%',
    borderTopLeftRadius: RADIUS.lg,
    borderTopRightRadius: RADIUS.lg,
    borderWidth: StyleSheet.hairlineWidth,
    borderBottomWidth: 0,
    paddingTop: SPACING.md,
    paddingHorizontal: SPACING.lg,
    paddingBottom: SPACING.lg
  },
  sheetHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginBottom: SPACING.sm
  },
  sheetTitle: {
    fontSize: 18,
    fontWeight: '800',
    flex: 1,
    paddingRight: SPACING.md
  },
  close: {
    fontSize: 16,
    fontWeight: '700'
  },
  sheetScroll: {
    paddingBottom: SPACING.xl
  },
  metricLine: {
    fontSize: 13,
    marginBottom: SPACING.sm
  },
  metricRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 6,
    gap: 8
  },
  metricDot: {
    width: 8,
    height: 8,
    borderRadius: 4
  },
  metricLabel: {
    flex: 1,
    fontSize: 14
  },
  metricValue: {
    fontSize: 14,
    fontWeight: '700'
  },
  body: {
    fontSize: 14,
    lineHeight: 20,
    marginTop: SPACING.sm,
    marginBottom: SPACING.md
  },
  subhead: {
    fontSize: 15,
    fontWeight: '700',
    marginBottom: 4
  },
  micro: {
    fontSize: 11,
    lineHeight: 15,
    marginBottom: SPACING.sm
  },
  breakRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    gap: SPACING.sm,
    paddingVertical: 6,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: 'rgba(128,128,128,0.2)'
  },
  cat: {
    flex: 1,
    fontSize: 13,
    fontWeight: '600'
  },
  brVal: {
    fontSize: 12,
    fontWeight: '600'
  },
  textArea: {
    borderRadius: RADIUS.md,
    borderWidth: StyleSheet.hairlineWidth,
    paddingHorizontal: SPACING.md,
    paddingVertical: SPACING.sm,
    minHeight: 88,
    textAlignVertical: 'top',
    fontSize: 14,
    marginTop: SPACING.xs
  }
});
