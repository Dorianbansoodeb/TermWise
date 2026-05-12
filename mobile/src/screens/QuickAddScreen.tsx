import React, { useState } from 'react';
import { Pressable, ScrollView, StyleSheet, Text, TextInput, View } from 'react-native';
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
import type { RootStackParamList } from '../navigation/constants';

type QuickAddScreenProps = NativeStackScreenProps<RootStackParamList, 'QuickAdd'>;

export function QuickAddScreen({ navigation }: QuickAddScreenProps) {
  const theme = useTheme();
  const { addTransaction } = useAppState();
  const [type, setType] = useState<'expense' | 'income'>('expense');
  const [amount, setAmount] = useState('');
  const [name, setName] = useState('');
  const [note, setNote] = useState('');
  const [category, setCategory] = useState(PRESET_EXPENSE_CATEGORIES[0] ?? 'Other');

  const presets = type === 'expense' ? PRESET_EXPENSE_CATEGORIES : PRESET_INCOME_CATEGORIES;

  const onSave = () => {
    const value = parseFloat(amount);
    if (!Number.isFinite(value) || value <= 0) return;
    addTransaction({
      amount: value,
      name: name.trim() || category,
      category,
      note: note.trim(),
      type
    });
    navigation.goBack();
  };

  return (
    <SafeAreaView style={[styles.root, { backgroundColor: theme.background }]} edges={['top']}>
      <View style={styles.headerRow}>
        <Text style={[styles.title, { color: theme.text }]}>Quick Add</Text>
        <Pressable
          onPress={navigation.goBack}
          hitSlop={12}
          style={({ pressed }) => [styles.close, { opacity: pressed ? 0.6 : 1 }]}
        >
          <Text style={[styles.closeLabel, { color: theme.text }]}>{'\u00D7'}</Text>
        </Pressable>
      </View>
      <ScrollView contentContainerStyle={styles.scroll} keyboardShouldPersistTaps="handled">
        <View style={[styles.typeRow, { backgroundColor: theme.surfaceMuted }]}>
          {(['expense', 'income'] as const).map((t) => {
            const selected = t === type;
            return (
              <Pressable
                key={t}
                onPress={() => {
                  setType(t);
                  const next = t === 'expense' ? PRESET_EXPENSE_CATEGORIES[0] : PRESET_INCOME_CATEGORIES[0];
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
          onChangeText={setAmount}
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

        <Text style={[styles.fieldLabel, { color: theme.textMuted }]}>Category</Text>
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

        <Text style={[styles.fieldLabel, { color: theme.textMuted }]}>Name (optional)</Text>
        <TextInput
          value={name}
          onChangeText={setName}
          placeholder={category}
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

        <Text style={[styles.fieldLabel, { color: theme.textMuted }]}>Note (optional)</Text>
        <TextInput
          value={note}
          onChangeText={setNote}
          placeholder="Coffee with Sam"
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

        <PrimaryButton title="Save Entry" onPress={onSave} style={{ marginTop: SPACING.md }} />
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  root: {
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
  }
});
