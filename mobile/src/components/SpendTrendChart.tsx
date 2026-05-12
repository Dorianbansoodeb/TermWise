import React, { useMemo, useState } from 'react';
import { LayoutChangeEvent, StyleSheet, Text, View } from 'react-native';
import { GestureDetector, Gesture } from 'react-native-gesture-handler';
import Svg, { Circle, Line, Path, Rect, Text as SvgText } from 'react-native-svg';
import type { ChartSeries } from '../utils/chartCalculator';
import { tooltipRowsForSlot } from '../utils/chartCalculator';
import { useTheme } from '../theme/useTheme';
import { RADIUS, SPACING } from '../theme/tokens';
import { formatCurrency } from '../utils/format';
import { shortMonthDay } from '../utils/date';

interface SpendTrendChartProps {
  series: ChartSeries;
  height?: number;
}

/// Lightweight SVG spending trend chart with: actual cumulative line (blue),
/// pace line, optional projection (dashed red), and per-slot tooltip. Designed
/// for parity with the SwiftUI `LineTrendChartView`.
export function SpendTrendChart({ series, height = 220 }: SpendTrendChartProps) {
  const theme = useTheme();
  const [width, setWidth] = useState(0);
  const [activeSlot, setActiveSlot] = useState<number | null>(null);

  const onLayout = (e: LayoutChangeEvent) => setWidth(e.nativeEvent.layout.width);

  const margin = { top: 16, right: 16, bottom: 24, left: 16 };
  const innerW = Math.max(0, width - margin.left - margin.right);
  const innerH = Math.max(0, height - margin.top - margin.bottom);

  const slotCount = series.slots.length;
  const todayIdx = Math.max(1, Math.min(series.todayIdx, slotCount));
  const todayChartIdx = todayIdx - 1;

  const dataMax = useMemo(() => {
    let maxValue = 0;
    for (const v of series.actualCumulative) maxValue = Math.max(maxValue, v);
    for (const v of series.paceCumulative) maxValue = Math.max(maxValue, v);
    for (const l of series.limitLines) maxValue = Math.max(maxValue, l.value);
    if (series.drawsProjectionLine) {
      maxValue = Math.max(maxValue, series.projectedEndValue);
    }
    return maxValue > 0 ? maxValue * 1.1 : 1;
  }, [series]);

  const xForSlot = (i: number) =>
    margin.left + (slotCount <= 1 ? 0 : (innerW * i) / (slotCount - 1));
  const yForValue = (v: number) =>
    margin.top + innerH - innerH * (Math.max(0, Math.min(v, dataMax)) / dataMax);

  const actualPath = useMemo(() => {
    if (slotCount === 0) return '';
    const lastDrawIdx = Math.min(todayChartIdx, slotCount - 1);
    const parts: string[] = [];
    for (let i = 0; i <= lastDrawIdx; i++) {
      const value = series.actualCumulative[i] ?? 0;
      const cmd = i === 0 ? 'M' : 'L';
      parts.push(`${cmd}${xForSlot(i).toFixed(2)} ${yForValue(value).toFixed(2)}`);
    }
    return parts.join(' ');
  }, [series, slotCount, todayChartIdx, innerW, innerH, dataMax]);

  const pacePath = useMemo(() => {
    if (slotCount === 0) return '';
    return series.paceCumulative
      .map(
        (value, i) =>
          `${i === 0 ? 'M' : 'L'}${xForSlot(i).toFixed(2)} ${yForValue(value).toFixed(2)}`
      )
      .join(' ');
  }, [series, slotCount, innerW, innerH, dataMax]);

  const projectionPath = useMemo(() => {
    if (!series.drawsProjectionLine || slotCount === 0) return '';
    const start = series.actualCumulative[todayChartIdx] ?? 0;
    return (
      `M${xForSlot(todayChartIdx).toFixed(2)} ${yForValue(start).toFixed(2)} ` +
      `L${xForSlot(slotCount - 1).toFixed(2)} ${yForValue(series.projectedEndValue).toFixed(2)}`
    );
  }, [series, todayChartIdx, slotCount, innerW, innerH, dataMax]);

  const selectedRows = useMemo(() => {
    if (activeSlot == null) return null;
    return tooltipRowsForSlot({ series, slotIndex: activeSlot });
  }, [activeSlot, series]);

  const panGesture = Gesture.Pan()
    .activateAfterLongPress(0)
    .minDistance(0)
    .onUpdate((e) => {
      if (slotCount === 0 || innerW <= 0) return;
      const x = e.x - margin.left;
      const rel = Math.max(0, Math.min(innerW, x));
      const slot = Math.round((rel / Math.max(1, innerW)) * (slotCount - 1));
      setActiveSlot(slot);
    })
    .onEnd(() => setActiveSlot(null))
    .onFinalize(() => setActiveSlot(null));

  const tap = Gesture.Tap().onStart((e) => {
    if (slotCount === 0 || innerW <= 0) return;
    const x = e.x - margin.left;
    const rel = Math.max(0, Math.min(innerW, x));
    const slot = Math.round((rel / Math.max(1, innerW)) * (slotCount - 1));
    setActiveSlot(slot);
  });
  const gesture = Gesture.Simultaneous(panGesture, tap);

  return (
    <View style={[styles.container, { height }]} onLayout={onLayout}>
      <GestureDetector gesture={gesture}>
        <View style={StyleSheet.absoluteFill}>
          {width > 0 && (
            <Svg width={width} height={height}>
              <Rect x={0} y={0} width={width} height={height} fill="transparent" />

              {/* Limit / Available lines */}
              {series.limitLines.map((line, idx) => {
                const y = yForValue(line.value);
                return (
                  <React.Fragment key={`${line.label}-${idx}`}>
                    <Line
                      x1={margin.left}
                      x2={margin.left + innerW}
                      y1={y}
                      y2={y}
                      stroke={line.color}
                      strokeWidth={1}
                      strokeDasharray={line.dashed ? '6 4' : undefined}
                    />
                    <SvgText
                      x={margin.left + innerW - 4}
                      y={Math.max(margin.top + 10, y - 4)}
                      fill={line.color}
                      fontSize={10}
                      fontWeight="600"
                      textAnchor="end"
                    >
                      {line.label}
                    </SvgText>
                  </React.Fragment>
                );
              })}

              {/* Today marker */}
              {todayChartIdx > 0 && todayChartIdx < slotCount - 1 && (
                <Line
                  x1={xForSlot(todayChartIdx)}
                  x2={xForSlot(todayChartIdx)}
                  y1={margin.top}
                  y2={margin.top + innerH}
                  stroke={theme.chartGrid}
                  strokeWidth={1}
                  strokeDasharray="2 4"
                />
              )}

              {/* Pace line */}
              {pacePath !== '' && (
                <Path
                  d={pacePath}
                  stroke={theme.chartPace}
                  strokeWidth={2}
                  fill="none"
                />
              )}

              {/* Actual line */}
              {actualPath !== '' && (
                <Path
                  d={actualPath}
                  stroke={theme.chartActual}
                  strokeWidth={2.5}
                  fill="none"
                />
              )}

              {/* Projection line */}
              {projectionPath !== '' && (
                <Path
                  d={projectionPath}
                  stroke={theme.chartProjection}
                  strokeWidth={2}
                  strokeDasharray="6 4"
                  fill="none"
                />
              )}

              {/* Selected dot */}
              {activeSlot != null && (
                <Circle
                  cx={xForSlot(activeSlot)}
                  cy={yForValue(
                    activeSlot <= todayChartIdx
                      ? series.actualCumulative[activeSlot] ?? 0
                      : projectedValueAt(series, activeSlot)
                  )}
                  r={5}
                  fill={
                    activeSlot <= todayChartIdx ? theme.chartActual : theme.chartProjection
                  }
                  stroke={theme.surface}
                  strokeWidth={2}
                />
              )}

              {/* X-axis date labels (start / today / end) */}
              <SvgText
                x={margin.left}
                y={height - 6}
                fill={theme.textMuted}
                fontSize={10}
                textAnchor="start"
              >
                {series.slots[0] ? shortMonthDay(series.slots[0]) : ''}
              </SvgText>
              <SvgText
                x={margin.left + innerW}
                y={height - 6}
                fill={theme.textMuted}
                fontSize={10}
                textAnchor="end"
              >
                {series.slots[slotCount - 1] ? shortMonthDay(series.slots[slotCount - 1]!) : ''}
              </SvgText>
            </Svg>
          )}
        </View>
      </GestureDetector>

      {selectedRows && (
        <View
          pointerEvents="none"
          style={[
            styles.tooltip,
            {
              backgroundColor: theme.surface,
              borderColor: theme.border,
              top: SPACING.sm,
              left: SPACING.sm
            }
          ]}
        >
          <Text style={[styles.tooltipDate, { color: theme.textMuted }]}>
            {shortMonthDay(selectedRows.date)}
          </Text>
          {selectedRows.rows.map((row) => (
            <View key={row.label} style={styles.tooltipRow}>
              <Text style={[styles.tooltipLabel, { color: theme.textMuted }]}>{row.label}</Text>
              <Text style={[styles.tooltipValue, { color: theme.text }]}>
                {formatCurrency(row.value, { compact: true })}
              </Text>
            </View>
          ))}
        </View>
      )}
    </View>
  );
}

function projectedValueAt(series: ChartSeries, slotIndex: number): number {
  const startIdx = Math.max(0, series.todayIdx - 1);
  const startValue = series.actualCumulative[startIdx] ?? 0;
  const endIdx = series.slots.length - 1;
  if (endIdx <= startIdx) return startValue;
  const t = (slotIndex - startIdx) / (endIdx - startIdx);
  return startValue + Math.max(0, t) * (series.projectedEndValue - startValue);
}

const styles = StyleSheet.create({
  container: {
    position: 'relative',
    width: '100%'
  },
  tooltip: {
    position: 'absolute',
    paddingVertical: SPACING.xs + 2,
    paddingHorizontal: SPACING.sm,
    borderRadius: RADIUS.sm,
    borderWidth: StyleSheet.hairlineWidth,
    minWidth: 140
  },
  tooltipDate: {
    fontSize: 11,
    fontWeight: '600',
    marginBottom: 2
  },
  tooltipRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    paddingVertical: 1
  },
  tooltipLabel: {
    fontSize: 11
  },
  tooltipValue: {
    fontSize: 11,
    fontWeight: '600',
    marginLeft: SPACING.md
  }
});
