import React, { useEffect, useMemo, useRef, useState } from 'react';
import {
  Animated,
  Easing,
  LayoutChangeEvent,
  Pressable,
  StyleSheet,
  Text,
  View
} from 'react-native';
import Svg, { Circle, Path, Text as SvgText } from 'react-native-svg';
import { useTheme } from '../theme/useTheme';
import { SPACING } from '../theme/tokens';
import { Card } from './Card';
import { useAppState } from '../state/AppState';
import { colorForCategory } from '../utils/categories';
import type { BudgetItem } from '../types/models';
import type { ThemePalette } from '../theme/tokens';
import { monthYearLabel } from '../utils/date';
import {
  budgetPlannedPieSlices,
  OTHER_VARIABLE_SLICE_ID,
  studentBudgetBenchmarkLines,
  totalPlannedPieAmount,
  type BudgetPlannedPieSlice
} from '../utils/budgetPlanVisualization';
import { budgetDifference, totalBudgeted, unallocatedRow } from '../utils/financeCalculator';

interface BudgetPlanningPieCardProps {
  budgetItems: BudgetItem[];
  availableToBudget: number;
  referenceDate: Date;
  onEditSlice?: (slice: BudgetPlannedPieSlice) => void;
}

const PIE_SIZE = 120;
const CX = PIE_SIZE / 2;
const CY = PIE_SIZE / 2;
const R = 52;

const PIE_LARGE = 220;
const CX_L = PIE_LARGE / 2;
const CY_L = PIE_LARGE / 2;
const R_L = 88;

const COLLAPSED_PIE_SCALE = PIE_SIZE / PIE_LARGE;

function formatSlicePct(value: number, total: number): string {
  if (total <= 0) return '0%';
  const p = (value / total) * 100;
  if (p >= 10) return `${Math.round(p)}%`;
  if (p >= 1) return `${Math.round(p * 10) / 10}%`;
  return `${Math.round(p * 100) / 100}%`;
}

function wedgePath(cx: number, cy: number, r: number, t0: number, t1: number): string {
  const a0 = -Math.PI / 2 + t0 * Math.PI * 2;
  const a1 = -Math.PI / 2 + t1 * Math.PI * 2;
  const x0 = cx + r * Math.cos(a0);
  const y0 = cy + r * Math.sin(a0);
  const x1 = cx + r * Math.cos(a1);
  const y1 = cy + r * Math.sin(a1);
  const largeArc = a1 - a0 > Math.PI ? 1 : 0;
  return `M ${cx} ${cy} L ${x0} ${y0} A ${r} ${r} 0 ${largeArc} 1 ${x1} ${y1} Z`;
}

function sliceColorsForTheme(theme: ThemePalette): string[] {
  return [
    theme.chartActual,
    theme.accent,
    theme.chartPace,
    theme.warning,
    theme.positive,
    theme.chartLimit
  ];
}

function decorateSlices(slices: BudgetPlannedPieSlice[], theme: ThemePalette) {
  const fixedPalette = sliceColorsForTheme(theme);
  let fixedIdx = 0;
  return slices.map((slice) => ({
    slice,
    color:
      slice.kind === 'variable'
        ? slice.id === OTHER_VARIABLE_SLICE_ID
          ? theme.chartLimit
          : colorForCategory(slice.label)
        : fixedPalette[fixedIdx++ % fixedPalette.length]!
  }));
}

interface LargeWedge {
  key: string;
  slice: BudgetPlannedPieSlice;
  color: string;
  d: string;
  pctStr: string;
  showPctLabel: boolean;
  lx: number;
  ly: number;
}

function buildLargeWedges(
  decorated: ReturnType<typeof decorateSlices>,
  total: number
): LargeWedge[] {
  if (total <= 0) return [];
  let cum = 0;
  return decorated.map(({ slice, color }) => {
    const t0 = cum;
    cum += slice.value / total;
    const tMid = (t0 + cum) / 2;
    const pct = (slice.value / total) * 100;
    const lr = R_L * (pct < 5 ? 0.45 : 0.58);
    const ang = -Math.PI / 2 + tMid * Math.PI * 2;
    return {
      key: slice.id,
      slice,
      color,
      d: wedgePath(CX_L, CY_L, R_L, t0, cum),
      pctStr: formatSlicePct(slice.value, total),
      showPctLabel: pct >= 3.5,
      lx: CX_L + lr * Math.cos(ang),
      ly: CY_L + lr * Math.sin(ang)
    };
  });
}

/// Planned budget mix (small pie) with expandable breakdown: enlarged interactive pie, rows, rough guide.
export function BudgetPlanningPieCard({
  budgetItems,
  availableToBudget,
  referenceDate,
  onEditSlice
}: BudgetPlanningPieCardProps) {
  const theme = useTheme();
  const { formatMoney } = useAppState();
  const [width, setWidth] = useState(0);
  const [panelVisible, setPanelVisible] = useState(false);
  const [panelClosing, setPanelClosing] = useState(false);
  const [pressedSliceId, setPressedSliceId] = useState<string | null>(null);

  const pieScale = useRef(new Animated.Value(COLLAPSED_PIE_SCALE)).current;
  const panelOpacity = useRef(new Animated.Value(0)).current;
  const smallHeaderScale = useRef(new Animated.Value(1)).current;

  useEffect(() => {
    if (!panelVisible) setPressedSliceId(null);
  }, [panelVisible]);

  const onLayout = (e: LayoutChangeEvent) => setWidth(e.nativeEvent.layout.width);

  const slices = useMemo(() => budgetPlannedPieSlices(budgetItems), [budgetItems]);
  const decorated = useMemo(() => decorateSlices(slices, theme), [slices, theme]);
  const total = totalPlannedPieAmount(slices);

  const openPanel = () => {
    setPanelClosing(false);
    pieScale.stopAnimation();
    panelOpacity.stopAnimation();
    smallHeaderScale.stopAnimation();
    setPanelVisible(true);
    pieScale.setValue(COLLAPSED_PIE_SCALE);
    panelOpacity.setValue(0);
    requestAnimationFrame(() => {
      const anims: Animated.CompositeAnimation[] = [
        Animated.timing(panelOpacity, {
          toValue: 1,
          duration: 240,
          useNativeDriver: true
        })
      ];
      if (total > 0) {
        anims.push(
          Animated.spring(pieScale, {
            toValue: 1,
            useNativeDriver: true,
            friction: 7,
            tension: 68
          })
        );
      }
      Animated.parallel(anims).start();
    });
  };

  const CLOSE_MS = 240;

  const closePanel = () => {
    pieScale.stopAnimation();
    panelOpacity.stopAnimation();
    smallHeaderScale.stopAnimation();

    setPanelClosing(true);
    if (total > 0) {
      smallHeaderScale.setValue(COLLAPSED_PIE_SCALE);
    }

    requestAnimationFrame(() => {
      const anims: Animated.CompositeAnimation[] = [
        Animated.timing(panelOpacity, {
          toValue: 0,
          duration: CLOSE_MS,
          easing: Easing.in(Easing.cubic),
          useNativeDriver: true
        })
      ];
      if (total > 0) {
        anims.push(
          Animated.timing(pieScale, {
            toValue: COLLAPSED_PIE_SCALE,
            duration: CLOSE_MS,
            easing: Easing.in(Easing.cubic),
            useNativeDriver: true
          }),
          Animated.timing(smallHeaderScale, {
            toValue: 1,
            duration: CLOSE_MS,
            easing: Easing.out(Easing.cubic),
            useNativeDriver: true
          })
        );
      }
      Animated.parallel(anims).start(({ finished }) => {
        if (finished) {
          setPanelVisible(false);
          setPanelClosing(false);
          setPressedSliceId(null);
          smallHeaderScale.setValue(1);
        }
      });
    });
  };

  const togglePanel = () => {
    if (panelVisible) closePanel();
    else openPanel();
  };

  const totalBudgetedAmount = useMemo(() => totalBudgeted(budgetItems), [budgetItems]);
  const isOverBudget = useMemo(
    () => total > 0 && budgetDifference(availableToBudget, totalBudgetedAmount) < 0,
    [total, availableToBudget, totalBudgetedAmount]
  );
  const envelopeRow = useMemo(
    () => unallocatedRow(availableToBudget, totalBudgetedAmount),
    [availableToBudget, totalBudgetedAmount]
  );
  const benchmarkLines = useMemo(
    () => studentBudgetBenchmarkLines(budgetItems, availableToBudget),
    [budgetItems, availableToBudget]
  );

  const paths = useMemo(() => {
    if (total <= 0 || isOverBudget) return [];
    let cum = 0;
    return decorated.map(({ slice, color }) => {
      const t0 = cum;
      cum += slice.value / total;
      return {
        key: slice.id,
        d: wedgePath(CX, CY, R, t0, cum),
        color
      };
    });
  }, [decorated, total, isOverBudget]);

  const largeWedges = useMemo(
    () => (!isOverBudget ? buildLargeWedges(decorated, total) : []),
    [decorated, total, isOverBudget]
  );

  const pressedWedge = useMemo(
    () => largeWedges.find((w) => w.key === pressedSliceId),
    [largeWedges, pressedSliceId]
  );

  const monthLine = monthYearLabel(referenceDate);

  const narrow = width > 0 && width < 380;

  return (
    <Card onLayout={onLayout}>
      <Text style={[styles.title, { color: theme.text }]}>Month breakdown</Text>
      <Text style={[styles.monthLine, { color: theme.textMuted }]}>{monthLine}</Text>
      <Text style={[styles.subtitle, { color: theme.textMuted }]}>
        {
          total > 0
            ? "Planned slice of your budget this month. Open the breakdown for an enlarged, tappable chart and every category's share."
            : 'Open the breakdown below for context on typical student budget bands.'
        }
      </Text>

      {total <= 0 ? (
        <Text style={[styles.empty, { color: theme.textMuted }]}>
          Add recurring bills or variable categories with planned amounts to see your allocation
          chart.
        </Text>
      ) : (
        <View style={[styles.topRow, narrow && styles.topRowStack]}>
          {!panelVisible || panelClosing ? (
            <Animated.View
              style={[
                styles.pieWrap,
                {
                  width: PIE_SIZE,
                  height: PIE_SIZE,
                  transform: [{ scale: smallHeaderScale }]
                }
              ]}
            >
              <Svg width={PIE_SIZE} height={PIE_SIZE}>
                {isOverBudget ? (
                  <>
                    <Circle cx={CX} cy={CY} r={R} fill={theme.danger} />
                    <SvgText
                      x={CX}
                      y={CY}
                      fill="#ffffff"
                      fontSize={11}
                      fontWeight="700"
                      textAnchor="middle"
                      alignmentBaseline="central"
                    >
                      Over budget
                    </SvgText>
                  </>
                ) : (
                  paths.map((p) => (
                    <Path key={p.key} d={p.d} fill={p.color} stroke={theme.card} strokeWidth={1} />
                  ))
                )}
              </Svg>
            </Animated.View>
          ) : null}
          <View style={[styles.summaryCol, panelVisible && styles.summaryColExpanded]}>
            <Text style={[styles.summaryLabel, { color: theme.textMuted }]}>Total planned</Text>
            <Text style={[styles.summaryValue, { color: theme.text }]}>{formatMoney(total)}</Text>
            {isOverBudget ? (
              <Text style={[styles.summaryOver, { color: theme.danger }]}>
                {envelopeRow.label} {formatMoney(envelopeRow.value)}
              </Text>
            ) : null}
          </View>
        </View>
      )}

      <Pressable
        onPress={togglePanel}
        style={({ pressed }) => [
          styles.dropdownHeader,
          {
            backgroundColor: theme.surfaceMuted,
            borderColor: theme.border,
            opacity: pressed ? 0.88 : 1,
            marginBottom: panelVisible ? SPACING.xs : SPACING.md
          }
        ]}
        accessibilityRole="button"
        accessibilityState={{ expanded: panelVisible }}
        accessibilityLabel="Toggle enlarged breakdown, tap chart for percentages, and rough guide"
      >
        <Text style={[styles.dropdownTitle, { color: theme.text }]}>
          {panelVisible ? 'Hide' : 'Show'} breakdown
        </Text>
        <Text style={[styles.dropdownChevron, { color: theme.textMuted }]}>
          {panelVisible ? '\u25BC' : '\u25B6'}
        </Text>
      </Pressable>

      {panelVisible ? (
        <Animated.View
          style={[
            styles.breakdownPanel,
            {
              backgroundColor: theme.surface,
              borderColor: theme.border,
              opacity: panelOpacity
            }
          ]}
        >
          {total > 0 ? (
            <View style={styles.largePieBlock}>
              <Animated.View
                style={{
                  width: PIE_LARGE,
                  height: PIE_LARGE,
                  alignSelf: 'center',
                  transform: [{ scale: pieScale }]
                }}
              >
                <Svg width={PIE_LARGE} height={PIE_LARGE} style={styles.largePieSvg}>
                {isOverBudget ? (
                  <>
                    <Circle cx={CX_L} cy={CY_L} r={R_L} fill={theme.danger} />
                    <SvgText
                      x={CX_L}
                      y={CY_L}
                      fill="#ffffff"
                      fontSize={14}
                      fontWeight="700"
                      textAnchor="middle"
                      alignmentBaseline="central"
                    >
                      Over budget
                    </SvgText>
                  </>
                ) : (
                  <>
                    {largeWedges.map((w) => (
                      <Path
                        key={w.key}
                        d={w.d}
                        fill={w.color}
                        stroke={pressedSliceId === w.slice.id ? '#ffffff' : theme.card}
                        strokeWidth={pressedSliceId === w.slice.id ? 3 : 1}
                        onPress={() =>
                          setPressedSliceId((id) => (id === w.slice.id ? null : w.slice.id))
                        }
                      />
                    ))}
                    {largeWedges.map((w) =>
                      w.showPctLabel ? (
                        <SvgText
                          key={`lbl-${w.key}`}
                          x={w.lx}
                          y={w.ly}
                          fill="#ffffff"
                          fontSize={12}
                          fontWeight="700"
                          textAnchor="middle"
                          alignmentBaseline="central"
                          pointerEvents="none"
                        >
                          {w.pctStr}
                        </SvgText>
                      ) : null
                    )}
                  </>
                )}
              </Svg>
              </Animated.View>
              {!isOverBudget ? (
                <>
                  {pressedWedge ? (
                    <Text style={[styles.sliceCaption, { color: theme.text }]}>
                      {pressedWedge.slice.label} — {pressedWedge.pctStr} (
                      {formatMoney(pressedWedge.slice.value)})
                    </Text>
                  ) : (
                    <Text style={[styles.tapHint, { color: theme.textMuted }]}>
                      {
                        "Tap a wedge to highlight it. Percentages on the chart are each slice's share of Total Budgeted."
                      }
                    </Text>
                  )}
                </>
              ) : null}
            </View>
          ) : null}

          {total > 0
            ? decorated.map(({ slice, color }) => {
                const canEdit = !!onEditSlice && slice.id !== OTHER_VARIABLE_SLICE_ID;
                const openEditor = () => onEditSlice?.(slice);

                const row = (
                  <>
                    <View style={[styles.breakdownDot, { backgroundColor: color }]} />
                    <View style={styles.breakdownMid}>
                      <View style={styles.breakdownNameRow}>
                        <Text
                          style={[styles.breakdownName, { color: theme.text }]}
                          numberOfLines={2}
                        >
                          {slice.label}
                        </Text>
                        {canEdit ? (
                          <Pressable
                            onPress={openEditor}
                            hitSlop={8}
                            accessibilityRole="button"
                            accessibilityLabel={`Edit ${slice.label}`}
                            style={({ pressed }) => [
                              styles.editIconBtn,
                              {
                                borderColor: theme.border,
                                backgroundColor: theme.surfaceMuted,
                                opacity: pressed ? 0.65 : 1
                              }
                            ]}
                          >
                            <Text style={[styles.editIcon, { color: theme.textMuted }]}>✎</Text>
                          </Pressable>
                        ) : null}
                      </View>
                      <Text style={[styles.breakdownAmt, { color: theme.textMuted }]}>
                        {formatMoney(slice.value)}
                      </Text>
                    </View>
                    <Text style={[styles.breakdownPct, { color: theme.text }]}>
                      {formatSlicePct(slice.value, total)}
                    </Text>
                  </>
                );

                return canEdit ? (
                  <Pressable
                    key={slice.id}
                    onPress={openEditor}
                    accessibilityRole="button"
                    accessibilityLabel={`Edit ${slice.label}`}
                    style={({ pressed }) => [
                      styles.breakdownRow,
                      { opacity: pressed ? 0.88 : 1 }
                    ]}
                  >
                    {row}
                  </Pressable>
                ) : (
                  <View key={slice.id} style={styles.breakdownRow}>
                    {row}
                  </View>
                );
              })
            : null}
          <View
            style={
              total > 0
                ? {
                    borderTopColor: theme.border,
                    borderTopWidth: StyleSheet.hairlineWidth,
                    marginTop: SPACING.md,
                    paddingTop: SPACING.md
                  }
                : { paddingTop: 0 }
            }
          >
            <Text style={[styles.statTitle, { color: theme.text }]}>Rough guide</Text>
            {benchmarkLines.map((line, idx) => (
              <Text key={idx} style={[styles.statBody, { color: theme.textMuted }]}>
                {line}
              </Text>
            ))}
          </View>
        </Animated.View>
      ) : null}
    </Card>
  );
}

const styles = StyleSheet.create({
  title: {
    fontSize: 17,
    fontWeight: '800',
    marginBottom: 2
  },
  monthLine: {
    fontSize: 13,
    fontWeight: '600',
    marginBottom: SPACING.sm
  },
  subtitle: {
    fontSize: 12,
    lineHeight: 17,
    marginBottom: SPACING.md
  },
  empty: {
    fontSize: 13,
    lineHeight: 18,
    marginBottom: SPACING.md
  },
  topRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: SPACING.lg,
    marginBottom: SPACING.md
  },
  topRowStack: {
    flexDirection: 'column',
    alignItems: 'flex-start'
  },
  pieWrap: {
    alignSelf: 'flex-start'
  },
  summaryCol: {
    flex: 1,
    justifyContent: 'center',
    minWidth: 100
  },
  summaryColExpanded: {
    minWidth: 0,
    width: '100%'
  },
  summaryLabel: {
    fontSize: 11,
    fontWeight: '700',
    letterSpacing: 0.3,
    textTransform: 'uppercase',
    marginBottom: 2
  },
  summaryValue: {
    fontSize: 20,
    fontWeight: '800'
  },
  summaryOver: {
    fontSize: 12,
    fontWeight: '700',
    marginTop: SPACING.xs
  },
  dropdownHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingVertical: SPACING.sm + 2,
    paddingHorizontal: SPACING.md,
    borderRadius: 12,
    borderWidth: StyleSheet.hairlineWidth
  },
  dropdownTitle: {
    fontSize: 14,
    fontWeight: '700',
    flex: 1,
    paddingRight: SPACING.sm
  },
  dropdownChevron: {
    fontSize: 12,
    fontWeight: '700'
  },
  breakdownPanel: {
    borderRadius: 12,
    borderWidth: StyleSheet.hairlineWidth,
    padding: SPACING.md,
    marginBottom: SPACING.sm,
    gap: 0
  },
  largePieBlock: {
    alignItems: 'center',
    marginBottom: SPACING.md
  },
  largePieSvg: {
    alignSelf: 'center'
  },
  tapHint: {
    fontSize: 12,
    lineHeight: 17,
    textAlign: 'center',
    marginTop: SPACING.sm,
    paddingHorizontal: SPACING.sm
  },
  sliceCaption: {
    fontSize: 14,
    fontWeight: '700',
    textAlign: 'center',
    marginTop: SPACING.sm,
    paddingHorizontal: SPACING.sm
  },
  breakdownRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: SPACING.sm,
    paddingVertical: 8
  },
  breakdownDot: {
    width: 10,
    height: 10,
    borderRadius: 5
  },
  breakdownMid: {
    flex: 1,
    minWidth: 0
  },
  breakdownNameRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: SPACING.xs
  },
  breakdownName: {
    fontSize: 13,
    fontWeight: '600',
    flexShrink: 1
  },
  editIconBtn: {
    width: 26,
    height: 26,
    borderRadius: 13,
    borderWidth: StyleSheet.hairlineWidth,
    alignItems: 'center',
    justifyContent: 'center'
  },
  editIcon: {
    fontSize: 13,
    lineHeight: 15,
    fontWeight: '700'
  },
  breakdownAmt: {
    fontSize: 12,
    marginTop: 2
  },
  breakdownPct: {
    fontSize: 14,
    fontWeight: '800',
    minWidth: 52,
    textAlign: 'right'
  },
  statTitle: {
    fontSize: 12,
    fontWeight: '700',
    letterSpacing: 0.4,
    textTransform: 'uppercase',
    marginBottom: SPACING.sm
  },
  statBody: {
    fontSize: 12,
    lineHeight: 18,
    marginBottom: SPACING.sm
  }
});
