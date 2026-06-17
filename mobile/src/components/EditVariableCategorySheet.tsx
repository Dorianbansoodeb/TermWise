import React, { useEffect, useState } from 'react';
import {
  Alert,
  KeyboardAvoidingView,
  Modal,
  Platform,
  Pressable,
  StyleSheet,
  Text,
  TextInput,
  View
} from 'react-native';
import { PrimaryButton } from './PrimaryButton';
import { useTheme } from '../theme/useTheme';
import { RADIUS, SPACING } from '../theme/tokens';
import type { BudgetItem } from '../types/models';

interface EditVariableCategorySheetProps {
  visible: boolean;
  item: BudgetItem | null;
  onCancel: () => void;
  onSave: (patch: { category: string; planned: number }) => void;
  onDelete: () => void;
}

/// Modal sheet for editing a Variable Spending category. Currently exposes
/// `category` name and `planned` monthly limit — the two fields a user is
/// most likely to tweak. Mirrors the contained, slide-up presentation used
/// by Quick Add.
export function EditVariableCategorySheet({
  visible,
  item,
  onCancel,
  onSave,
  onDelete
}: EditVariableCategorySheetProps) {
  const theme = useTheme();
  const [name, setName] = useState('');
  const [limit, setLimit] = useState('');

  useEffect(() => {
    if (!visible || !item) return;
    setName(item.category);
    setLimit(formatLimit(item.planned));
  }, [visible, item]);

  const trimmedName = name.trim();
  const parsedLimit = parseFloat(limit.trim());
  const limitValid = Number.isFinite(parsedLimit) && parsedLimit >= 0;
  const canSave = trimmedName.length > 0 && limitValid;

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
          <Text style={[styles.title, { color: theme.text }]}>Edit Variable Category</Text>
          <Text style={[styles.helper, { color: theme.textMuted }]}>
            Update the category name or its monthly limit. Status and progress recalculate
            automatically.
          </Text>

          <Text style={[styles.label, { color: theme.textMuted }]}>Category name</Text>
          <TextInput
            value={name}
            onChangeText={setName}
            placeholder="Groceries"
            placeholderTextColor={theme.textMuted}
            style={[
              styles.input,
              { color: theme.text, borderColor: theme.border, backgroundColor: theme.surface }
            ]}
          />

          <Text style={[styles.label, { color: theme.textMuted }]}>Monthly limit ($)</Text>
          <TextInput
            value={limit}
            onChangeText={setLimit}
            keyboardType="decimal-pad"
            placeholder="0"
            placeholderTextColor={theme.textMuted}
            style={[
              styles.input,
              {
                color: theme.text,
                borderColor: limitValid ? theme.border : theme.danger,
                backgroundColor: theme.surface
              }
            ]}
          />

          <PrimaryButton
            title="Delete Category"
            variant="danger"
            onPress={() => {
              Alert.alert(
                'Delete variable category?',
                'This removes the category from your budget plan. Past transactions keep their category label.',
                [
                  { text: 'Cancel', style: 'cancel' },
                  { text: 'Delete', style: 'destructive', onPress: onDelete }
                ]
              );
            }}
          />

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
                onSave({ category: trimmedName, planned: Math.max(0, parsedLimit) });
              }}
              style={{ flex: 1 }}
              disabled={!canSave}
            />
          </View>
        </View>
      </KeyboardAvoidingView>
    </Modal>
  );
}

function formatLimit(value: number): string {
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
    padding: SPACING.lg,
    paddingBottom: SPACING.xxl
  },
  grabber: {
    alignSelf: 'center',
    width: 40,
    height: 4,
    borderRadius: 2,
    marginBottom: SPACING.md
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
  actions: {
    flexDirection: 'row',
    gap: SPACING.sm,
    marginTop: SPACING.lg
  }
});
