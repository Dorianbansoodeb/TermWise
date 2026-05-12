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
import { useTheme } from '../theme/useTheme';
import { RADIUS, SPACING } from '../theme/tokens';
import type { BudgetItem, PaymentFrequency } from '../types/models';

interface EditRecurringBillSheetProps {
  visible: boolean;
  item: BudgetItem | null;
  onCancel: () => void;
  onSave: (patch: {
    category: string;
    planned: number;
    dueDay: number | undefined;
    frequency: PaymentFrequency;
  }) => void;
}

const FREQ_OPTIONS: { value: PaymentFrequency; label: string }[] = [
  { value: 'monthly', label: 'Monthly' },
  { value: 'weekly', label: 'Weekly' },
  { value: 'biweekly', label: 'Biweekly' },
  { value: 'oneTime', label: 'One-time' }
];

/// Modal sheet for editing a Recurring Bill (`budgetType === 'fixed'`).
/// Exposes the plan-side fields — bill name, planned amount, due day, and
/// recurrence. Actual paid stays driven by transactions (Mark as Paid /
/// Quick Add / Undo) so the edit sheet never destroys real payment history.
export function EditRecurringBillSheet({
  visible,
  item,
  onCancel,
  onSave
}: EditRecurringBillSheetProps) {
  const theme = useTheme();
  const [name, setName] = useState('');
  const [planned, setPlanned] = useState('');
  const [dueDay, setDueDay] = useState('');
  const [frequency, setFrequency] = useState<PaymentFrequency>('monthly');

  useEffect(() => {
    if (!visible || !item) return;
    setName(item.category);
    setPlanned(formatPlanned(item.planned));
    setDueDay(item.dueDay ? String(item.dueDay) : '');
    setFrequency(item.frequency ?? 'monthly');
  }, [visible, item]);

  const trimmedName = name.trim();
  const parsedPlanned = parseFloat(planned.trim());
  const plannedValid = Number.isFinite(parsedPlanned) && parsedPlanned >= 0;

  const dueDayValidation = useMemo(() => {
    const trimmed = dueDay.trim();
    if (trimmed === '') return { valid: true as const, value: undefined as number | undefined };
    const n = parseInt(trimmed, 10);
    if (!Number.isFinite(n) || n < 1 || n > 31) {
      return { valid: false as const, value: undefined };
    }
    return { valid: true as const, value: n };
  }, [dueDay]);

  const canSave = trimmedName.length > 0 && plannedValid && dueDayValidation.valid;

  return (
    <Modal
      visible={visible}
      transparent
      animationType="slide"
      onRequestClose={onCancel}
    >
      <KeyboardAvoidingView
        style={styles.backdrop}
        behavior={Platform.OS === 'ios' ? 'padding' : undefined}
      >
        <Pressable style={StyleSheet.absoluteFill} onPress={onCancel} />
        <View style={[styles.sheet, { backgroundColor: theme.card, borderColor: theme.border }]}>
          <View style={[styles.grabber, { backgroundColor: theme.border }]} />
          <ScrollView
            keyboardShouldPersistTaps="handled"
            contentContainerStyle={styles.scroll}
            showsVerticalScrollIndicator={false}
          >
            <Text style={[styles.title, { color: theme.text }]}>Edit Recurring Bill</Text>
            <Text style={[styles.helper, { color: theme.textMuted }]}>
              Update the bill's plan. Recorded payments are managed via Mark as Paid, Quick
              Add, and Undo — they are not changed by this edit.
            </Text>

            <Text style={[styles.label, { color: theme.textMuted }]}>Bill name</Text>
            <TextInput
              value={name}
              onChangeText={setName}
              placeholder="Rent"
              placeholderTextColor={theme.textMuted}
              style={[
                styles.input,
                { color: theme.text, borderColor: theme.border, backgroundColor: theme.surface }
              ]}
            />

            <Text style={[styles.label, { color: theme.textMuted }]}>Planned amount ($)</Text>
            <TextInput
              value={planned}
              onChangeText={setPlanned}
              keyboardType="decimal-pad"
              placeholder="0"
              placeholderTextColor={theme.textMuted}
              style={[
                styles.input,
                {
                  color: theme.text,
                  borderColor: plannedValid ? theme.border : theme.danger,
                  backgroundColor: theme.surface
                }
              ]}
            />

            <Text style={[styles.label, { color: theme.textMuted }]}>Due day of month (1-31)</Text>
            <TextInput
              value={dueDay}
              onChangeText={setDueDay}
              keyboardType="number-pad"
              placeholder="Optional"
              placeholderTextColor={theme.textMuted}
              style={[
                styles.input,
                {
                  color: theme.text,
                  borderColor: dueDayValidation.valid ? theme.border : theme.danger,
                  backgroundColor: theme.surface
                }
              ]}
            />
            {!dueDayValidation.valid ? (
              <Text style={[styles.error, { color: theme.danger }]}>
                Enter a day between 1 and 31, or leave blank.
              </Text>
            ) : null}

            <Text style={[styles.label, { color: theme.textMuted }]}>Recurrence</Text>
            <View style={styles.freqRow}>
              {FREQ_OPTIONS.map((opt) => {
                const selected = frequency === opt.value;
                return (
                  <Pressable
                    key={opt.value}
                    onPress={() => setFrequency(opt.value)}
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

            <View style={styles.actions}>
              <PrimaryButton
                title="Cancel"
                variant="ghost"
                onPress={onCancel}
                style={{ flex: 1 }}
              />
              <PrimaryButton
                title="Save"
                variant="primary"
                onPress={() => {
                  if (!canSave) return;
                  onSave({
                    category: trimmedName,
                    planned: Math.max(0, parsedPlanned),
                    dueDay: dueDayValidation.value,
                    frequency
                  });
                }}
                style={{ flex: 1 }}
                disabled={!canSave}
              />
            </View>
          </ScrollView>
        </View>
      </KeyboardAvoidingView>
    </Modal>
  );
}

function formatPlanned(value: number): string {
  if (!Number.isFinite(value)) return '';
  return value.toFixed(0);
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
    maxHeight: '85%'
  },
  scroll: {
    padding: SPACING.lg,
    paddingBottom: SPACING.xxl
  },
  grabber: {
    alignSelf: 'center',
    width: 40,
    height: 4,
    borderRadius: 2,
    marginTop: SPACING.sm
  },
  title: {
    fontSize: 18,
    fontWeight: '700'
  },
  helper: {
    fontSize: 12,
    marginTop: 4,
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
  error: {
    fontSize: 12,
    fontWeight: '600',
    marginTop: 4
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
  actions: {
    flexDirection: 'row',
    gap: SPACING.sm,
    marginTop: SPACING.lg
  }
});
