import React, { useMemo, useState } from 'react';
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
import {
  PRESET_EXPENSE_CATEGORIES,
  PRESET_INCOME_CATEGORIES,
  colorForCategory
} from '../utils/categories';
import { findFixedBillForCategory } from '../utils/financeCalculator';
import { addDays, dayKey, relativeDayLabel } from '../utils/date';
import type { RootStackParamList } from '../navigation/constants';

type QuickAddScreenProps = NativeStackScreenProps<RootStackParamList, 'QuickAdd'>;

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
  const [amount, setAmount] = useState('');
  const [name, setName] = useState('');
  const [note, setNote] = useState('');
  const [category, setCategory] = useState(PRESET_EXPENSE_CATEGORIES[0] ?? 'Other');
  const [dateInput, setDateInput] = useState(dayKey(new Date()));
  const [error, setError] = useState<string | null>(null);

  const presets = type === 'expense' ? PRESET_EXPENSE_CATEGORIES : PRESET_INCOME_CATEGORIES;

  const parsedDate = useMemo(() => parseYmd(dateInput), [dateInput]);
  const dateValid = parsedDate !== null;

  const todayKey = dayKey(new Date());
  const yesterdayKey = dayKey(addDays(new Date(), -1));

  const onSave = () => {
    const value = parseFloat(amount);
    if (!Number.isFinite(value) || value <= 0) {
      setError('Enter an amount greater than $0.');
      return;
    }
    if (!category.trim()) {
      setError('Pick a category.');
      return;
    }
    if (!parsedDate) {
      setError('Use a YYYY-MM-DD date.');
      return;
    }
    setError(null);
    const billMatch =
      type === 'expense' ? findFixedBillForCategory(category, budgetItems) : undefined;
    addTransaction({
      amount: value,
      name: name.trim() || category,
      category,
      note: note.trim(),
      type,
      date: parsedDate,
      billId: billMatch?.id,
      source: billMatch ? 'quickAdd' : undefined,
      undoable: Boolean(billMatch)
    });
    navigation.goBack();
  };

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
                    const next =
                      t === 'expense' ? PRESET_EXPENSE_CATEGORIES[0] : PRESET_INCOME_CATEGORIES[0];
                    if (next) setCategory(next);
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

          <Text style={[styles.fieldLabel, { color: theme.textMuted }]}>
            {type === 'expense' ? 'Category' : 'Income type'}
          </Text>
          <View style={styles.presetWrap}>
            {presets.map((p) => {
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

          <Text style={[styles.fieldLabel, { color: theme.textMuted }]}>Date</Text>
          <View style={styles.dateRow}>
            {[
              { label: 'Today', value: todayKey },
              { label: 'Yesterday', value: yesterdayKey }
            ].map((opt) => {
              const selected = dateInput === opt.value;
              return (
                <Pressable
                  key={opt.label}
                  onPress={() => setDateInput(opt.value)}
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
                    {opt.label}
                  </Text>
                </Pressable>
              );
            })}
            <TextInput
              value={dateInput}
              onChangeText={(v) => {
                setDateInput(v);
                if (error) setError(null);
              }}
              placeholder="YYYY-MM-DD"
              placeholderTextColor={theme.textMuted}
              autoCapitalize="none"
              autoCorrect={false}
              style={[
                styles.input,
                styles.dateInput,
                {
                  color: theme.text,
                  borderColor: dateValid ? theme.border : theme.danger,
                  backgroundColor: theme.surface
                }
              ]}
            />
          </View>
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
    alignItems: 'center'
  },
  typeLabel: {
    fontSize: 13
  },
  fieldLabel: {
    fontSize: 11,
    fontWeight: '700',
    letterSpacing: 0.4,
    textTransform: 'uppercase',
    marginTop: SPACING.md
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
  dateInput: {
    flexGrow: 1,
    flexBasis: 120,
    minWidth: 120,
    fontSize: 14
  },
  dateHint: {
    fontSize: 11,
    marginTop: 2
  },
  errorText: {
    fontSize: 13,
    fontWeight: '600',
    marginTop: SPACING.sm
  }
});
