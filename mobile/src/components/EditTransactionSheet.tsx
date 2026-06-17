import React, { useEffect, useMemo, useState } from 'react';
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
import { PrimaryButton } from './PrimaryButton';
import { useAppState } from '../state/AppState';
import { useTheme } from '../theme/useTheme';
import { RADIUS, SPACING } from '../theme/tokens';
import type { TransactionItem } from '../types/models';
import { isUndoableMarkAsPaidTransaction } from '../types/models';
import { PRESET_INCOME_CATEGORIES, colorForCategory } from '../utils/categories';
import { addDays, calendarDateISO, dayKey, parseCalendarDate, relativeDayLabel } from '../utils/date';

interface EditTransactionSheetProps {
  visible: boolean;
  transaction: TransactionItem | null;
  onCancel: () => void;
  onSave: (
    patch: Partial<Pick<TransactionItem, 'amount' | 'name' | 'category' | 'note' | 'date'>>
  ) => void;
}

export function EditTransactionSheet({
  visible,
  transaction,
  onCancel,
  onSave
}: EditTransactionSheetProps) {
  const theme = useTheme();
  const { budgetItems } = useAppState();
  const [amount, setAmount] = useState('');
  const [name, setName] = useState('');
  const [category, setCategory] = useState('');
  const [note, setNote] = useState('');
  const [dateInput, setDateInput] = useState('');

  const readOnly = transaction ? isUndoableMarkAsPaidTransaction(transaction) : false;

  useEffect(() => {
    if (!visible || !transaction) return;
    setAmount(formatAmount(transaction.amount));
    setName(transaction.name);
    setCategory(transaction.category);
    setNote(transaction.note);
    setDateInput(dayKey(parseCalendarDate(transaction.date)));
  }, [visible, transaction]);

  const parsedDate = useMemo(() => parseYmd(dateInput), [dateInput]);
  const dateValid = parsedDate !== null;
  const todayKey = dayKey(new Date());
  const yesterdayKey = dayKey(addDays(new Date(), -1));
  const parsedAmount = parseFloat(amount.trim());
  const amountValid = Number.isFinite(parsedAmount) && parsedAmount > 0;
  const categoryValid = category.trim().length > 0;
  const canSave = !readOnly && amountValid && categoryValid && dateValid;

  const categoryPresets = useMemo(() => {
    if (!transaction) return [];
    if (transaction.type === 'income') return PRESET_INCOME_CATEGORIES;
    return [
      ...new Set(
        budgetItems
          .filter((b) => b.budgetType === 'fixed' || b.budgetType === 'variable')
          .map((b) => b.category)
      )
    ];
  }, [transaction, budgetItems]);

  return (
    <Modal visible={visible} transparent animationType="slide" onRequestClose={onCancel}>
      <KeyboardAvoidingView
        style={styles.backdrop}
        behavior={Platform.OS === 'ios' ? 'padding' : undefined}
      >
        <Pressable style={StyleSheet.absoluteFill} onPress={onCancel} />
        <View style={[styles.sheet, { backgroundColor: theme.card, borderColor: theme.border }]}>
          <View style={[styles.grabber, { backgroundColor: theme.border }]} />
          <Text style={[styles.title, { color: theme.text }]}>
            {readOnly ? 'Transaction Details' : 'Edit Transaction'}
          </Text>
          {readOnly ? (
            <Text style={[styles.helper, { color: theme.textMuted }]}>
              This payment was created by Mark as Paid. Use Undo on the snackbar to reverse it, or
              delete the row — it cannot be edited.
            </Text>
          ) : (
            <Text style={[styles.helper, { color: theme.textMuted }]}>
              Update amount, name, category, date, or note.
            </Text>
          )}

          <ScrollView keyboardShouldPersistTaps="handled" contentContainerStyle={styles.form}>
            <Text style={[styles.label, { color: theme.textMuted }]}>Amount</Text>
            <TextInput
              value={amount}
              onChangeText={setAmount}
              editable={!readOnly}
              keyboardType="decimal-pad"
              placeholder="0.00"
              placeholderTextColor={theme.textMuted}
              style={[
                styles.input,
                styles.amountInput,
                {
                  color: theme.text,
                  borderColor: amountValid || readOnly ? theme.border : theme.danger,
                  backgroundColor: theme.surface,
                  opacity: readOnly ? 0.6 : 1
                }
              ]}
            />

            <Text style={[styles.label, { color: theme.textMuted }]}>Name</Text>
            <TextInput
              value={name}
              onChangeText={setName}
              editable={!readOnly}
              placeholder="Merchant or source"
              placeholderTextColor={theme.textMuted}
              style={[
                styles.input,
                {
                  color: theme.text,
                  borderColor: theme.border,
                  backgroundColor: theme.surface,
                  opacity: readOnly ? 0.6 : 1
                }
              ]}
            />

            <Text style={[styles.label, { color: theme.textMuted }]}>Category</Text>
            {!readOnly && categoryPresets.length > 0 ? (
              <View style={styles.presetWrap}>
                {categoryPresets.map((preset) => {
                  const selected = preset === category;
                  return (
                    <Pressable
                      key={preset}
                      onPress={() => setCategory(preset)}
                      style={[
                        styles.preset,
                        {
                          backgroundColor: selected ? theme.surfaceMuted : theme.surface,
                          borderColor: selected ? theme.text : theme.border
                        }
                      ]}
                    >
                      <View
                        style={[styles.presetDot, { backgroundColor: colorForCategory(preset) }]}
                      />
                      <Text style={[styles.presetLabel, { color: theme.text }]}>{preset}</Text>
                    </Pressable>
                  );
                })}
              </View>
            ) : null}
            <TextInput
              value={category}
              onChangeText={setCategory}
              editable={!readOnly}
              placeholder="Category"
              placeholderTextColor={theme.textMuted}
              style={[
                styles.input,
                {
                  color: theme.text,
                  borderColor: categoryValid || readOnly ? theme.border : theme.danger,
                  backgroundColor: theme.surface,
                  opacity: readOnly ? 0.6 : 1
                }
              ]}
            />

            <Text style={[styles.label, { color: theme.textMuted }]}>Date</Text>
            {!readOnly ? (
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
                  onChangeText={setDateInput}
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
            ) : (
              <Text style={[styles.readOnlyDate, { color: theme.text }]}>
                {parsedDate ? relativeDayLabel(parsedDate) : dateInput}
              </Text>
            )}
            {parsedDate && !readOnly ? (
              <Text style={[styles.dateHint, { color: theme.textMuted }]}>
                {relativeDayLabel(parsedDate)}
              </Text>
            ) : null}

            <Text style={[styles.label, { color: theme.textMuted }]}>Note (optional)</Text>
            <TextInput
              value={note}
              onChangeText={setNote}
              editable={!readOnly}
              placeholder="Optional note"
              placeholderTextColor={theme.textMuted}
              style={[
                styles.input,
                {
                  color: theme.text,
                  borderColor: theme.border,
                  backgroundColor: theme.surface,
                  opacity: readOnly ? 0.6 : 1
                }
              ]}
            />
          </ScrollView>

          <View style={styles.actions}>
            <PrimaryButton
              title={readOnly ? 'Close' : 'Cancel'}
              variant="ghost"
              onPress={onCancel}
              style={{ flex: 1 }}
            />
            {!readOnly ? (
              <PrimaryButton
                title="Save"
                variant="primary"
                onPress={() => {
                  if (!canSave || !parsedDate) return;
                  onSave({
                    amount: Math.max(0, parsedAmount),
                    name: name.trim() || category.trim(),
                    category: category.trim(),
                    note,
                    date: calendarDateISO(parsedDate)
                  });
                }}
                style={{ flex: 1 }}
                disabled={!canSave}
              />
            ) : null}
          </View>
        </View>
      </KeyboardAvoidingView>
    </Modal>
  );
}

function formatAmount(value: number): string {
  if (!Number.isFinite(value)) return '';
  return value % 1 === 0 ? value.toFixed(0) : value.toFixed(2);
}

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
  backdrop: { flex: 1, backgroundColor: 'rgba(0,0,0,0.35)', justifyContent: 'flex-end' },
  sheet: {
    borderTopLeftRadius: RADIUS.xl,
    borderTopRightRadius: RADIUS.xl,
    borderTopWidth: StyleSheet.hairlineWidth,
    padding: SPACING.lg,
    paddingBottom: SPACING.xxl,
    maxHeight: '90%'
  },
  grabber: { alignSelf: 'center', width: 40, height: 4, borderRadius: 2, marginBottom: SPACING.md },
  title: { fontSize: 18, fontWeight: '700' },
  helper: { fontSize: 12, marginTop: 4, marginBottom: SPACING.sm },
  form: { paddingBottom: SPACING.sm },
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
  amountInput: { fontSize: 22, fontWeight: '700' },
  presetWrap: { flexDirection: 'row', flexWrap: 'wrap', gap: SPACING.sm, marginBottom: SPACING.xs },
  preset: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: SPACING.sm + 2,
    paddingVertical: 6,
    borderRadius: RADIUS.pill,
    borderWidth: StyleSheet.hairlineWidth
  },
  presetDot: { width: 8, height: 8, borderRadius: 4, marginRight: 6 },
  presetLabel: { fontSize: 12, fontWeight: '600' },
  dateRow: { flexDirection: 'row', alignItems: 'center', flexWrap: 'wrap', gap: SPACING.sm },
  dateChip: {
    paddingHorizontal: SPACING.sm + 2,
    paddingVertical: 6,
    borderRadius: RADIUS.pill,
    borderWidth: StyleSheet.hairlineWidth
  },
  dateChipLabel: { fontSize: 12, fontWeight: '600' },
  dateInput: { flexGrow: 1, flexBasis: 120, minWidth: 120, fontSize: 14 },
  dateHint: { fontSize: 11, marginTop: 2 },
  readOnlyDate: { fontSize: 15, fontWeight: '600' },
  actions: { flexDirection: 'row', gap: SPACING.sm, marginTop: SPACING.md }
});
