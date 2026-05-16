import React, { useEffect, useState } from 'react';
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
import type { PaymentFrequency } from '../types/models';
import {
  buildRecurringBudgetItemDraft,
  buildVariableBudgetItemDraft,
  type NewBudgetItemDraft,
  validateRecurringBillAdd,
  validateVariableCategoryAdd
} from '../utils/budgetItemAdd';
import { PrimaryButton } from './PrimaryButton';
import { useTheme } from '../theme/useTheme';
import { RADIUS, SPACING } from '../theme/tokens';

export interface AddBudgetItemSheetProps {
  visible: boolean;
  onClose: () => void;
  onAdd: (draft: NewBudgetItemDraft) => void;
}

const FREQ_OPTIONS: { value: PaymentFrequency; label: string }[] = [
  { value: 'monthly', label: 'Monthly' },
  { value: 'weekly', label: 'Weekly' },
  { value: 'biweekly', label: 'Biweekly' },
  { value: 'oneTime', label: 'One-time' }
];

type AddKind = 'recurring' | 'variable';

/// Bottom sheet: add a fixed recurring bill or a variable spending category.
export function AddBudgetItemSheet({ visible, onClose, onAdd }: AddBudgetItemSheetProps) {
  const theme = useTheme();
  const [kind, setKind] = useState<AddKind>('recurring');
  const [billName, setBillName] = useState('');
  const [monthlyAmount, setMonthlyAmount] = useState('');
  const [frequency, setFrequency] = useState<PaymentFrequency>('monthly');
  const [dueDay, setDueDay] = useState('');
  const [dueDate, setDueDate] = useState('');
  const [note, setNote] = useState('');
  const [categoryName, setCategoryName] = useState('');
  const [monthlyLimit, setMonthlyLimit] = useState('');
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!visible) return;
    setKind('recurring');
    setBillName('');
    setMonthlyAmount('');
    setFrequency('monthly');
    setDueDay('');
    setDueDate('');
    setNote('');
    setCategoryName('');
    setMonthlyLimit('');
    setError(null);
  }, [visible]);

  const handleSave = () => {
    setError(null);
    if (kind === 'recurring') {
      const planned = parseFloat(monthlyAmount.trim());
      const v = validateRecurringBillAdd({
        categoryTrimmed: billName.trim(),
        planned,
        frequency,
        dueDayStr: dueDay,
        dueDateStr: dueDate
      });
      if (!v.ok) {
        setError(v.message);
        return;
      }
      onAdd(
        buildRecurringBudgetItemDraft({
          category: billName,
          planned,
          frequency,
          dueDay: v.dueDay,
          dueDate: v.dueDate,
          memo: note
        })
      );
      onClose();
      return;
    }

    const limit = parseFloat(monthlyLimit.trim());
    const v = validateVariableCategoryAdd({
      categoryTrimmed: categoryName.trim(),
      limit
    });
    if (!v.ok) {
      setError(v.message);
      return;
    }
    onAdd(buildVariableBudgetItemDraft({ category: categoryName, planned: limit }));
    onClose();
  };

  const showDueDateField = kind === 'recurring' && frequency === 'oneTime';
  const dueDayLabel =
    kind === 'recurring' && frequency === 'monthly'
      ? 'Due day of month (1–31)'
      : 'Due day of month (optional)';

  return (
    <Modal visible={visible} transparent animationType="slide" onRequestClose={onClose}>
      <KeyboardAvoidingView
        style={styles.backdrop}
        behavior={Platform.OS === 'ios' ? 'padding' : undefined}
      >
        <Pressable style={StyleSheet.absoluteFill} onPress={onClose} />
        <View style={[styles.sheet, { backgroundColor: theme.card, borderColor: theme.border }]}>
          <View style={[styles.grabber, { backgroundColor: theme.border }]} />
          <ScrollView
            keyboardShouldPersistTaps="handled"
            contentContainerStyle={styles.scroll}
            showsVerticalScrollIndicator={false}
          >
            <View style={styles.headerRow}>
              <Text style={[styles.title, { color: theme.text, flex: 1 }]}>Add Budget Item</Text>
              <Pressable
                onPress={onClose}
                hitSlop={12}
                accessibilityRole="button"
                accessibilityLabel="Close"
              >
                <Text style={[styles.closeMark, { color: theme.textMuted }]}>✕</Text>
              </Pressable>
            </View>
            <Text style={[styles.helper, { color: theme.textMuted }]}>
              Choose whether this is a recurring bill or a flexible spending category, then fill in
              the details.
            </Text>

            <Text style={[styles.label, { color: theme.textMuted }]}>Type</Text>
            <View style={styles.typeRow}>
              {(
                [
                  { value: 'recurring' as const, label: 'Recurring Bill' },
                  { value: 'variable' as const, label: 'Variable Spending' }
                ] as const
              ).map((opt) => {
                const selected = kind === opt.value;
                return (
                  <Pressable
                    key={opt.value}
                    onPress={() => {
                      setKind(opt.value);
                      setError(null);
                    }}
                    style={({ pressed }) => [
                      styles.typePill,
                      {
                        backgroundColor: selected ? theme.primary : theme.surface,
                        borderColor: selected ? theme.primary : theme.border,
                        opacity: pressed ? 0.85 : 1
                      }
                    ]}
                  >
                    <Text
                      style={[
                        styles.typePillLabel,
                        { color: selected ? theme.primaryText : theme.text }
                      ]}
                    >
                      {opt.label}
                    </Text>
                  </Pressable>
                );
              })}
            </View>

            {error ? (
              <Text style={[styles.errorBanner, { color: theme.danger }]}>{error}</Text>
            ) : null}

            {kind === 'recurring' ? (
              <>
                <Text style={[styles.label, { color: theme.textMuted }]}>Bill name</Text>
                <TextInput
                  value={billName}
                  onChangeText={(t) => {
                    setBillName(t);
                    setError(null);
                  }}
                  placeholder="Electric"
                  placeholderTextColor={theme.textMuted}
                  style={[
                    styles.input,
                    { color: theme.text, borderColor: theme.border, backgroundColor: theme.surface }
                  ]}
                />

                <Text style={[styles.label, { color: theme.textMuted }]}>Monthly amount ($)</Text>
                <TextInput
                  value={monthlyAmount}
                  onChangeText={(t) => {
                    setMonthlyAmount(t);
                    setError(null);
                  }}
                  keyboardType="decimal-pad"
                  placeholder="0"
                  placeholderTextColor={theme.textMuted}
                  style={[
                    styles.input,
                    { color: theme.text, borderColor: theme.border, backgroundColor: theme.surface }
                  ]}
                />

                <Text style={[styles.label, { color: theme.textMuted }]}>Frequency</Text>
                <View style={styles.freqRow}>
                  {FREQ_OPTIONS.map((opt) => {
                    const selected = frequency === opt.value;
                    return (
                      <Pressable
                        key={opt.value}
                        onPress={() => {
                          setFrequency(opt.value);
                          setError(null);
                        }}
                        style={({ pressed }) => [
                          styles.freqPill,
                          {
                            backgroundColor: selected ? theme.primary : theme.surface,
                            borderColor: selected ? theme.primary : theme.border,
                            opacity: pressed ? 0.85 : 1
                          }
                        ]}
                      >
                        <Text
                          style={[
                            styles.freqLabel,
                            { color: selected ? theme.primaryText : theme.text }
                          ]}
                        >
                          {opt.label}
                        </Text>
                      </Pressable>
                    );
                  })}
                </View>

                {showDueDateField ? (
                  <>
                    <Text style={[styles.label, { color: theme.textMuted }]}>
                      Due date (YYYY-MM-DD, optional)
                    </Text>
                    <TextInput
                      value={dueDate}
                      onChangeText={(t) => {
                        setDueDate(t);
                        setError(null);
                      }}
                      placeholder="2026-05-01"
                      placeholderTextColor={theme.textMuted}
                      autoCapitalize="none"
                      style={[
                        styles.input,
                        {
                          color: theme.text,
                          borderColor: theme.border,
                          backgroundColor: theme.surface
                        }
                      ]}
                    />
                    <Text style={[styles.inlineHint, { color: theme.textMuted }]}>
                      If you skip a date, you can optionally set a due day of month below instead.
                    </Text>
                  </>
                ) : null}

                {!showDueDateField || dueDate.trim() === '' ? (
                  <>
                    <Text style={[styles.label, { color: theme.textMuted }]}>{dueDayLabel}</Text>
                    <TextInput
                      value={dueDay}
                      onChangeText={(t) => {
                        setDueDay(t);
                        setError(null);
                      }}
                      keyboardType="number-pad"
                      placeholder={frequency === 'monthly' ? '15' : 'Optional'}
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

                <Text style={[styles.label, { color: theme.textMuted }]}>Note (optional)</Text>
                <TextInput
                  value={note}
                  onChangeText={setNote}
                  placeholder="Anything you want to remember"
                  placeholderTextColor={theme.textMuted}
                  multiline
                  style={[
                    styles.input,
                    styles.noteInput,
                    { color: theme.text, borderColor: theme.border, backgroundColor: theme.surface }
                  ]}
                />
              </>
            ) : (
              <>
                <Text style={[styles.label, { color: theme.textMuted }]}>Category name</Text>
                <TextInput
                  value={categoryName}
                  onChangeText={(t) => {
                    setCategoryName(t);
                    setError(null);
                  }}
                  placeholder="Dining out"
                  placeholderTextColor={theme.textMuted}
                  style={[
                    styles.input,
                    { color: theme.text, borderColor: theme.border, backgroundColor: theme.surface }
                  ]}
                />

                <Text style={[styles.label, { color: theme.textMuted }]}>Monthly limit ($)</Text>
                <TextInput
                  value={monthlyLimit}
                  onChangeText={(t) => {
                    setMonthlyLimit(t);
                    setError(null);
                  }}
                  keyboardType="decimal-pad"
                  placeholder="0"
                  placeholderTextColor={theme.textMuted}
                  style={[
                    styles.input,
                    { color: theme.text, borderColor: theme.border, backgroundColor: theme.surface }
                  ]}
                />
                <Text style={[styles.inlineHint, { color: theme.textMuted }]}>
                  Category colors in charts follow your category name automatically.
                </Text>
              </>
            )}

            <View style={styles.saveWrap}>
              <PrimaryButton title="Save" variant="primary" onPress={handleSave} />
            </View>
          </ScrollView>
        </View>
      </KeyboardAvoidingView>
    </Modal>
  );
}

const styles = StyleSheet.create({
  backdrop: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.35)',
    justifyContent: 'flex-end'
  },
  sheet: {
    borderTopLeftRadius: RADIUS.xl,
    borderTopRightRadius: RADIUS.xl,
    borderTopWidth: StyleSheet.hairlineWidth,
    maxHeight: '88%'
  },
  grabber: {
    alignSelf: 'center',
    width: 40,
    height: 4,
    borderRadius: 2,
    marginTop: SPACING.sm
  },
  scroll: {
    padding: SPACING.lg,
    paddingBottom: SPACING.xxl
  },
  headerRow: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    marginBottom: SPACING.xs
  },
  title: {
    fontSize: 18,
    fontWeight: '700'
  },
  closeMark: {
    fontSize: 22,
    fontWeight: '500',
    paddingLeft: SPACING.sm,
    paddingTop: 2
  },
  helper: {
    fontSize: 12,
    marginBottom: SPACING.md
  },
  label: {
    fontSize: 11,
    fontWeight: '700',
    letterSpacing: 0.4,
    textTransform: 'uppercase',
    marginTop: SPACING.sm,
    marginBottom: SPACING.xs
  },
  input: {
    borderRadius: RADIUS.md,
    borderWidth: StyleSheet.hairlineWidth,
    paddingHorizontal: SPACING.md,
    paddingVertical: SPACING.sm + 2,
    fontSize: 15
  },
  noteInput: {
    minHeight: 72,
    textAlignVertical: 'top'
  },
  typeRow: {
    flexDirection: 'row',
    gap: SPACING.sm,
    marginBottom: SPACING.sm
  },
  typePill: {
    flex: 1,
    paddingVertical: SPACING.sm,
    paddingHorizontal: SPACING.sm,
    borderRadius: RADIUS.pill,
    borderWidth: 1,
    alignItems: 'center'
  },
  typePillLabel: {
    fontSize: 13,
    fontWeight: '600',
    textAlign: 'center'
  },
  freqRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: SPACING.sm
  },
  freqPill: {
    paddingVertical: SPACING.xs + 2,
    paddingHorizontal: SPACING.md,
    borderRadius: RADIUS.pill,
    borderWidth: 1
  },
  freqLabel: {
    fontSize: 13,
    fontWeight: '600'
  },
  errorBanner: {
    fontSize: 13,
    fontWeight: '600',
    marginTop: SPACING.sm
  },
  inlineHint: {
    fontSize: 11,
    marginTop: 4,
    marginBottom: SPACING.xs
  },
  saveWrap: {
    marginTop: SPACING.lg
  }
});
