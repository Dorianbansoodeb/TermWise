import React, { useEffect, useMemo, useRef, useState } from 'react';
import {
  KeyboardAvoidingView,
  Platform,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  View
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import type { NativeStackScreenProps } from '@react-navigation/native-stack';
import { useAppState } from '../state/AppState';
import { useTheme } from '../theme/useTheme';
import { RADIUS, SPACING } from '../theme/tokens';
import { PrimaryButton } from '../components/PrimaryButton';
import { PRESET_INCOME_CATEGORIES, colorForCategory } from '../utils/categories';
import { findFixedBillForCategory } from '../utils/financeCalculator';
import { addDays, dayKey, relativeDayLabel } from '../utils/date';
import type { BudgetItem } from '../types/models';
import type { RootStackParamList } from '../navigation/constants';

type QuickAddScreenProps = NativeStackScreenProps<RootStackParamList, 'QuickAdd'>;

type ExpenseRoute = 'fixed' | 'variable';
type DatePreset = 'today' | 'yesterday' | 'custom';

const NEW_TARGET = '__new__';
const ONE_TIME_TARGET = 'oneTime';

function pickDefaultExpenseSelection(items: BudgetItem[]): {
  route: ExpenseRoute;
  targetId: string;
  category: string;
} {
  const fixed = items.filter((b) => b.budgetType === 'fixed');
  const variable = items.filter((b) => b.budgetType === 'variable');
  if (variable[0]) {
    return { route: 'variable', targetId: variable[0].id, category: variable[0].category };
  }
  if (fixed[0]) {
    return { route: 'fixed', targetId: fixed[0].id, category: fixed[0].category };
  }
  return { route: 'variable', targetId: ONE_TIME_TARGET, category: '' };
}

function detectExpenseRoute(category: string, budgetItems: BudgetItem[]): ExpenseRoute {
  return findFixedBillForCategory(category.trim(), budgetItems) ? 'fixed' : 'variable';
}

/// Quick Add modal. Single source of truth for adding expense/income
/// transactions from the orange + FAB.
///
/// Routes the saved transaction through `useAppState().addTransaction` which
/// handles:
///   - persistence (AsyncStorage)
///   - income prompt ("Add to budget / Keep as reserve / Cancel")
///   - "Fully paid X" snackbar when an expense closes out a recurring bill
export function QuickAddScreen({ navigation }: QuickAddScreenProps) {
  const theme = useTheme();
  const { addTransaction, budgetItems } = useAppState();
  const [type, setType] = useState<'expense' | 'income'>('expense');
  const [expenseRoute, setExpenseRoute] = useState<ExpenseRoute>('variable');
  const [expenseTargetId, setExpenseTargetId] = useState<string>(ONE_TIME_TARGET);
  const [category, setCategory] = useState('');
  const [amount, setAmount] = useState('');
  const [name, setName] = useState('');
  const [note, setNote] = useState('');
  const [datePreset, setDatePreset] = useState<DatePreset>('today');
  const [customDateInput, setCustomDateInput] = useState('');
  const [advancedOpen, setAdvancedOpen] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const hydratedExpenseDefaults = useRef(false);

  const expenseCategories = useMemo(
    () => budgetItems.filter((b) => b.budgetType === 'fixed' || b.budgetType === 'variable'),
    [budgetItems]
  );

  const incomePresets = PRESET_INCOME_CATEGORIES;

  const todayKey = dayKey(new Date());
  const yesterdayKey = dayKey(addDays(new Date(), -1));

  const dateInput =
    datePreset === 'today' ? todayKey : datePreset === 'yesterday' ? yesterdayKey : customDateInput;

  const parsedDate = useMemo(() => parseYmd(dateInput), [dateInput]);
  const dateValid = parsedDate !== null;

  function applyExpenseSelection(next: { route: ExpenseRoute; targetId: string; category: string }) {
    setExpenseRoute(next.route);
    setExpenseTargetId(next.targetId);
    setCategory(next.category);
  }

  function initializeExpenseSelection() {
    applyExpenseSelection(pickDefaultExpenseSelection(budgetItems));
  }

  useEffect(() => {
    if (hydratedExpenseDefaults.current || budgetItems.length === 0) return;
    hydratedExpenseDefaults.current = true;
    applyExpenseSelection(pickDefaultExpenseSelection(budgetItems));
  }, [budgetItems]);

  const showCategoryField =
    type === 'expense' &&
    (expenseTargetId === NEW_TARGET || expenseTargetId === ONE_TIME_TARGET);

  function resolveExpenseBillId(): string | undefined {
    if (expenseRoute !== 'fixed') return undefined;
    if (expenseTargetId && expenseTargetId !== NEW_TARGET && expenseTargetId !== ONE_TIME_TARGET) {
      const bi = budgetItems.find((b) => b.id === expenseTargetId);
      if (bi?.budgetType === 'fixed') return bi.id;
    }
    return findFixedBillForCategory(category.trim(), budgetItems)?.id;
  }

  const onSave = () => {
    const value = parseFloat(amount);
    if (!Number.isFinite(value) || value <= 0) {
      setError('Enter an amount greater than $0.');
      return;
    }
    if (!parsedDate) {
      setError('Use a YYYY-MM-DD date.');
      return;
    }
    if (type === 'income') {
      if (!category.trim()) {
        setError('Pick an income type.');
        return;
      }
      setError(null);
      addTransaction({
        amount: value,
        name: name.trim() || category,
        category,
        note: note.trim(),
        type: 'income',
        date: parsedDate,
        undoable: false
      });
      navigation.goBack();
      return;
    }

    if (!category.trim()) {
      if (expenseTargetId === ONE_TIME_TARGET) {
        setError(
          'Enter what this one-time purchase was for (for example Pet adoption, furniture).'
        );
      } else {
        setError('Pick a category or use Advanced for one-time / new categories.');
      }
      return;
    }
    setError(null);
    const billId = resolveExpenseBillId();
    addTransaction({
      amount: value,
      name: name.trim() || category.trim(),
      category: category.trim(),
      note: note.trim(),
      type: 'expense',
      date: parsedDate,
      billId,
      source: billId ? 'quickAdd' : undefined,
      undoable: Boolean(billId)
    });
    navigation.goBack();
  };

  function selectBudgetLine(item: BudgetItem) {
    setError(null);
    setExpenseTargetId(item.id);
    setCategory(item.category);
    setExpenseRoute(item.budgetType === 'fixed' ? 'fixed' : 'variable');
  }

  function selectNewCategory() {
    setError(null);
    setExpenseTargetId(NEW_TARGET);
    setCategory('');
    setExpenseRoute('variable');
  }

  function selectOneTime() {
    setError(null);
    setExpenseTargetId(ONE_TIME_TARGET);
    setCategory('');
    setExpenseRoute('variable');
  }

  function handleExpenseRouteChange(route: ExpenseRoute) {
    setError(null);
    setExpenseRoute(route);
    if (expenseTargetId !== NEW_TARGET && expenseTargetId !== ONE_TIME_TARGET) {
      const current = budgetItems.find((b) => b.id === expenseTargetId);
      if (current && current.budgetType !== route) {
        const next = budgetItems.find((b) => b.budgetType === route);
        if (next) {
          selectBudgetLine(next);
        } else if (route === 'variable') {
          selectOneTime();
        } else {
          selectNewCategory();
        }
      }
    }
  }

  function handleCategoryTextChange(value: string) {
    setCategory(value);
    if (error) setError(null);
    if (expenseTargetId === NEW_TARGET) {
      setExpenseRoute(detectExpenseRoute(value, budgetItems));
    }
  }

  function selectDatePreset(preset: DatePreset) {
    setDatePreset(preset);
    if (error) setError(null);
    if (preset === 'custom' && !customDateInput.trim()) {
      setCustomDateInput(todayKey);
    }
  }

  return (
    <SafeAreaView style={[styles.root, { backgroundColor: theme.background }]} edges={['top']}>
      <KeyboardAvoidingView
        style={styles.flex}
        behavior={Platform.OS === 'ios' ? 'padding' : undefined}
      >
        <View style={styles.headerRow}>
          <Text style={[styles.title, { color: theme.text }]}>Quick Add</Text>
          <Pressable
            onPress={navigation.goBack}
            hitSlop={12}
            accessibilityLabel="Close Quick Add"
            style={({ pressed }) => [styles.close, { opacity: pressed ? 0.6 : 1 }]}
          >
            <Text style={[styles.closeLabel, { color: theme.text }]}>{'\u00D7'}</Text>
          </Pressable>
        </View>

        <ScrollView
          contentContainerStyle={styles.scroll}
          keyboardShouldPersistTaps="handled"
          showsVerticalScrollIndicator={false}
        >
          <View style={[styles.typeRow, { backgroundColor: theme.surfaceMuted }]}>
            {(['expense', 'income'] as const).map((t) => {
              const selected = t === type;
              return (
                <Pressable
                  key={t}
                  onPress={() => {
                    setType(t);
                    setError(null);
                    if (t === 'income') {
                      setCategory(PRESET_INCOME_CATEGORIES[0] ?? 'Other');
                    } else {
                      initializeExpenseSelection();
                    }
                  }}
                  style={[
                    styles.typeSegment,
                    selected && { backgroundColor: theme.surface, borderColor: theme.border }
                  ]}
                >
                  <Text
                    style={[
                      styles.typeLabel,
                      {
                        color: selected ? theme.text : theme.textMuted,
                        fontWeight: selected ? '700' : '500'
                      }
                    ]}
                  >
                    {t === 'expense' ? 'Expense' : 'Income'}
                  </Text>
                </Pressable>
              );
            })}
          </View>

          {type === 'expense' ? (
            <>
              <Text style={[styles.fieldLabel, { color: theme.textMuted }]}>Category</Text>
              <View style={styles.presetWrap}>
                {expenseCategories.map((item) => {
                  const selected = expenseTargetId === item.id;
                  return (
                    <Pressable
                      key={item.id}
                      onPress={() => selectBudgetLine(item)}
                      style={[
                        styles.preset,
                        {
                          backgroundColor: selected ? theme.surfaceMuted : theme.surface,
                          borderColor: selected ? theme.text : theme.border
                        }
                      ]}
                    >
                      <View
                        style={[
                          styles.presetDot,
                          { backgroundColor: colorForCategory(item.category) }
                        ]}
                      />
                      <Text style={[styles.presetLabel, { color: theme.text }]}>
                        {item.category}
                      </Text>
                    </Pressable>
                  );
                })}
              </View>
            </>
          ) : (
            <>
              <Text style={[styles.fieldLabel, { color: theme.textMuted }]}>Income type</Text>
              <View style={styles.presetWrap}>
                {incomePresets.map((p) => {
                  const selected = p === category;
                  return (
                    <Pressable
                      key={p}
                      onPress={() => setCategory(p)}
                      style={[
                        styles.preset,
                        {
                          backgroundColor: selected ? theme.surfaceMuted : theme.surface,
                          borderColor: selected ? theme.text : theme.border
                        }
                      ]}
                    >
                      <View style={[styles.presetDot, { backgroundColor: colorForCategory(p) }]} />
                      <Text style={[styles.presetLabel, { color: theme.text }]}>{p}</Text>
                    </Pressable>
                  );
                })}
              </View>
            </>
          )}

          <Text style={[styles.fieldLabel, { color: theme.textMuted }]}>Amount</Text>
          <TextInput
            value={amount}
            onChangeText={(v) => {
              setAmount(v);
              if (error) setError(null);
            }}
            placeholder="0.00"
            keyboardType="decimal-pad"
            placeholderTextColor={theme.textMuted}
            style={[
              styles.input,
              styles.amountInput,
              {
                color: theme.text,
                borderColor: theme.border,
                backgroundColor: theme.surface
              }
            ]}
          />

          <Text style={[styles.fieldLabel, { color: theme.textMuted }]}>Date</Text>
          <View style={styles.dateRow}>
            {(
              [
                { preset: 'today' as const, label: 'Today' },
                { preset: 'yesterday' as const, label: 'Yesterday' },
                { preset: 'custom' as const, label: 'Custom' }
              ] as const
            ).map(({ preset, label }) => {
              const selected = datePreset === preset;
              return (
                <Pressable
                  key={preset}
                  onPress={() => selectDatePreset(preset)}
                  style={[
                    styles.dateChip,
                    {
                      backgroundColor: selected ? theme.primary : theme.surface,
                      borderColor: selected ? theme.primary : theme.border
                    }
                  ]}
                >
                  <Text
                    style={[
                      styles.dateChipLabel,
                      { color: selected ? theme.primaryText : theme.text }
                    ]}
                  >
                    {label}
                  </Text>
                </Pressable>
              );
            })}
          </View>
          {datePreset === 'custom' ? (
            <TextInput
              value={customDateInput}
              onChangeText={(v) => {
                setCustomDateInput(v);
                if (error) setError(null);
              }}
              placeholder="YYYY-MM-DD"
              placeholderTextColor={theme.textMuted}
              autoCapitalize="none"
              autoCorrect={false}
              style={[
                styles.input,
                styles.customDateInput,
                {
                  color: theme.text,
                  borderColor: dateValid ? theme.border : theme.danger,
                  backgroundColor: theme.surface
                }
              ]}
            />
          ) : null}
          {parsedDate ? (
            <Text style={[styles.dateHint, { color: theme.textMuted }]}>
              {relativeDayLabel(parsedDate)}
            </Text>
          ) : null}

          <Text style={[styles.fieldLabel, { color: theme.textMuted }]}>Note (optional)</Text>
          <TextInput
            value={note}
            onChangeText={setNote}
            placeholder={type === 'expense' ? 'Coffee with Sam' : 'Biweekly direct deposit'}
            placeholderTextColor={theme.textMuted}
            style={[
              styles.input,
              {
                color: theme.text,
                borderColor: theme.border,
                backgroundColor: theme.surface
              }
            ]}
          />

          <Pressable
            onPress={() => setAdvancedOpen((open) => !open)}
            accessibilityRole="button"
            accessibilityState={{ expanded: advancedOpen }}
            style={({ pressed }) => [
              styles.advancedToggle,
              { opacity: pressed ? 0.7 : 1 }
            ]}
          >
            <Text style={[styles.advancedLabel, { color: theme.textMuted }]}>
              Advanced {advancedOpen ? '\u25B2' : '\u25BC'}
            </Text>
          </Pressable>

          {advancedOpen ? (
            <View style={styles.advancedSection}>
              {type === 'expense' ? (
                <>
                  <Text style={[styles.fieldLabel, { color: theme.textMuted, marginTop: 0 }]}>
                    How should this expense count?
                  </Text>
                  <View style={[styles.typeRow, { backgroundColor: theme.surfaceMuted }]}>
                    {(
                      [
                        { route: 'fixed' as const, label: 'Recurring bill' },
                        { route: 'variable' as const, label: 'Variable spending' }
                      ] as const
                    ).map(({ route, label }) => {
                      const selected = expenseRoute === route;
                      return (
                        <Pressable
                          key={route}
                          onPress={() => handleExpenseRouteChange(route)}
                          style={[
                            styles.typeSegment,
                            selected && {
                              backgroundColor: theme.surface,
                              borderColor: theme.border
                            }
                          ]}
                        >
                          <Text
                            style={[
                              styles.typeLabel,
                              {
                                color: selected ? theme.text : theme.textMuted,
                                fontWeight: selected ? '700' : '500'
                              }
                            ]}
                            numberOfLines={2}
                          >
                            {label}
                          </Text>
                        </Pressable>
                      );
                    })}
                  </View>

                  <Text style={[styles.fieldLabel, { color: theme.textMuted }]}>Other options</Text>
                  <View style={styles.presetWrap}>
                    <Pressable
                      onPress={selectOneTime}
                      style={[
                        styles.preset,
                        styles.specialPill,
                        expenseTargetId === ONE_TIME_TARGET
                          ? {
                              backgroundColor: tintHex(theme.warning, '33'),
                              borderColor: theme.warning,
                              borderWidth: 2
                            }
                          : {
                              backgroundColor: theme.surface,
                              borderColor: theme.warning,
                              borderWidth: 1.5
                            }
                      ]}
                    >
                      <View style={[styles.presetDot, { backgroundColor: theme.warning }]} />
                      <Text
                        style={[
                          styles.presetLabel,
                          {
                            color:
                              expenseTargetId === ONE_TIME_TARGET ? theme.text : theme.warning
                          }
                        ]}
                      >
                        One-time
                      </Text>
                    </Pressable>
                    <Pressable
                      onPress={selectNewCategory}
                      style={[
                        styles.preset,
                        styles.specialPill,
                        expenseTargetId === NEW_TARGET
                          ? {
                              backgroundColor: tintHex(theme.accent, '33'),
                              borderColor: theme.accent,
                              borderWidth: 2
                            }
                          : {
                              backgroundColor: theme.surface,
                              borderColor: theme.accent,
                              borderWidth: 1.5
                            }
                      ]}
                    >
                      <View style={[styles.presetDot, { backgroundColor: theme.accent }]} />
                      <Text
                        style={[
                          styles.presetLabel,
                          {
                            color: expenseTargetId === NEW_TARGET ? theme.text : theme.accent
                          }
                        ]}
                      >
                        New…
                      </Text>
                    </Pressable>
                  </View>

                  {showCategoryField ? (
                    <>
                      <Text style={[styles.subLabel, { color: theme.textMuted }]}>
                        {expenseTargetId === ONE_TIME_TARGET
                          ? 'What was this for? (one-time — not counted against a variable limit)'
                          : 'Type a category name'}
                      </Text>
                      <TextInput
                        value={category}
                        onChangeText={handleCategoryTextChange}
                        placeholder={
                          expenseTargetId === ONE_TIME_TARGET
                            ? 'e.g. Pet adoption, new laptop, furniture delivery'
                            : 'Custom category'
                        }
                        placeholderTextColor={theme.textMuted}
                        style={[
                          styles.input,
                          {
                            color: theme.text,
                            borderColor: theme.border,
                            backgroundColor: theme.surface
                          }
                        ]}
                      />
                    </>
                  ) : null}
                </>
              ) : null}

              <Text style={[styles.fieldLabel, { color: theme.textMuted }]}>
                {type === 'expense' ? 'Merchant / Name' : 'Source / Name'}
              </Text>
              <TextInput
                value={name}
                onChangeText={setName}
                placeholder={
                  type === 'expense' ? 'Loblaws, Uber, Starbucks…' : 'Co-op employer, OSAP, etc.'
                }
                placeholderTextColor={theme.textMuted}
                style={[
                  styles.input,
                  {
                    color: theme.text,
                    borderColor: theme.border,
                    backgroundColor: theme.surface
                  }
                ]}
              />
            </View>
          ) : null}

          {error ? (
            <Text style={[styles.errorText, { color: theme.danger }]}>{error}</Text>
          ) : null}

          <PrimaryButton
            title={type === 'expense' ? 'Save Expense' : 'Save Income'}
            onPress={onSave}
            style={{ marginTop: SPACING.md }}
          />
        </ScrollView>
      </KeyboardAvoidingView>
    </SafeAreaView>
  );
}

/** Append 2-digit hex alpha to `#RRGGBB` for a light tint background. */
function tintHex(hex: string, alphaSuffix: string): string {
  if (hex.startsWith('#') && hex.length === 7) return `${hex}${alphaSuffix}`;
  return hex;
}

/// Parse a `YYYY-MM-DD` (or `YYYY-M-D`) string into a `Date` anchored at noon
/// local time. Returns `null` for invalid input. Noon keeps the date stable
/// across DST boundaries so `dayKey` round-trips.
function parseYmd(input: string): Date | null {
  const trimmed = input.trim();
  const match = /^(\d{4})-(\d{1,2})-(\d{1,2})$/.exec(trimmed);
  if (!match) return null;
  const yearStr = match[1];
  const monthStr = match[2];
  const dayStr = match[3];
  if (!yearStr || !monthStr || !dayStr) return null;
  const year = parseInt(yearStr, 10);
  const month = parseInt(monthStr, 10);
  const day = parseInt(dayStr, 10);
  if (!Number.isFinite(year) || !Number.isFinite(month) || !Number.isFinite(day)) return null;
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  const parsed = new Date(year, month - 1, day, 12, 0, 0, 0);
  if (parsed.getMonth() !== month - 1 || parsed.getDate() !== day) return null;
  return parsed;
}

const styles = StyleSheet.create({
  root: {
    flex: 1
  },
  flex: {
    flex: 1
  },
  scroll: {
    paddingHorizontal: SPACING.lg,
    paddingBottom: SPACING.xxl,
    gap: SPACING.sm
  },
  headerRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: SPACING.lg,
    paddingTop: SPACING.md,
    paddingBottom: SPACING.sm
  },
  title: {
    fontSize: 22,
    fontWeight: '800'
  },
  close: {
    width: 32,
    height: 32,
    alignItems: 'center',
    justifyContent: 'center'
  },
  closeLabel: {
    fontSize: 22,
    fontWeight: '700'
  },
  typeRow: {
    flexDirection: 'row',
    padding: 3,
    borderRadius: RADIUS.pill,
    marginBottom: SPACING.md
  },
  typeSegment: {
    flex: 1,
    paddingVertical: SPACING.sm,
    borderRadius: RADIUS.pill,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: 'transparent',
    alignItems: 'center',
    justifyContent: 'center'
  },
  typeLabel: {
    fontSize: 12,
    textAlign: 'center'
  },
  fieldLabel: {
    fontSize: 11,
    fontWeight: '700',
    letterSpacing: 0.4,
    textTransform: 'uppercase',
    marginTop: SPACING.md
  },
  subLabel: {
    fontSize: 12,
    marginTop: SPACING.xs,
    marginBottom: 4
  },
  input: {
    borderRadius: RADIUS.md,
    borderWidth: StyleSheet.hairlineWidth,
    paddingHorizontal: SPACING.md,
    paddingVertical: SPACING.sm + 2,
    fontSize: 15
  },
  amountInput: {
    fontSize: 24,
    fontWeight: '700'
  },
  presetWrap: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: SPACING.sm,
    marginTop: SPACING.xs
  },
  preset: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: SPACING.sm + 2,
    paddingVertical: 6,
    borderRadius: RADIUS.pill,
    borderWidth: StyleSheet.hairlineWidth
  },
  specialPill: {
    borderStyle: 'solid'
  },
  presetDot: {
    width: 8,
    height: 8,
    borderRadius: 4,
    marginRight: 6
  },
  presetLabel: {
    fontSize: 12,
    fontWeight: '600'
  },
  dateRow: {
    flexDirection: 'row',
    alignItems: 'center',
    flexWrap: 'wrap',
    gap: SPACING.sm,
    marginTop: SPACING.xs
  },
  dateChip: {
    paddingHorizontal: SPACING.sm + 2,
    paddingVertical: 6,
    borderRadius: RADIUS.pill,
    borderWidth: StyleSheet.hairlineWidth
  },
  dateChipLabel: {
    fontSize: 12,
    fontWeight: '600'
  },
  customDateInput: {
    marginTop: SPACING.xs,
    fontSize: 14
  },
  dateHint: {
    fontSize: 11,
    marginTop: 2
  },
  advancedToggle: {
    marginTop: SPACING.md,
    paddingVertical: SPACING.xs
  },
  advancedLabel: {
    fontSize: 12,
    fontWeight: '700',
    letterSpacing: 0.4,
    textTransform: 'uppercase'
  },
  advancedSection: {
    gap: SPACING.sm
  },
  errorText: {
    fontSize: 13,
    fontWeight: '600',
    marginTop: SPACING.sm
  }
});
