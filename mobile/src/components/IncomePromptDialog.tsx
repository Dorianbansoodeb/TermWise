import React from 'react';
import { Modal, StyleSheet, Text, View } from 'react-native';
import { PrimaryButton } from './PrimaryButton';
import { useTheme } from '../theme/useTheme';
import { RADIUS, SPACING } from '../theme/tokens';
import { formatCurrency } from '../utils/format';
import { useAppState } from '../state/AppState';

export function IncomePromptDialog() {
  const theme = useTheme();
  const { pendingIncomePrompt, resolveIncomePrompt } = useAppState();
  if (!pendingIncomePrompt) return null;

  return (
    <Modal transparent visible animationType="fade" onRequestClose={() => resolveIncomePrompt('cancel')}>
      <View style={styles.overlay}>
        <View style={[styles.card, { backgroundColor: theme.surface, borderColor: theme.border }]}>
          <Text style={[styles.title, { color: theme.text }]}>Add this income to your budget?</Text>
          <Text style={[styles.body, { color: theme.textMuted }]}>
            You recorded {formatCurrency(pendingIncomePrompt.amount)} as{' '}
            {pendingIncomePrompt.categoryName}. Choose how it should affect this month's
            Available to Budget. Tap Cancel to undo the income entry.
          </Text>
          <PrimaryButton
            title="Add to Budget"
            onPress={() => resolveIncomePrompt('addToBudget')}
            style={{ marginBottom: SPACING.sm }}
          />
          <PrimaryButton
            title="Keep as Reserve"
            variant="secondary"
            onPress={() => resolveIncomePrompt('keepAsReserve')}
            style={{ marginBottom: SPACING.sm }}
          />
          <PrimaryButton
            title="Cancel"
            variant="ghost"
            onPress={() => resolveIncomePrompt('cancel')}
          />
        </View>
      </View>
    </Modal>
  );
}

const styles = StyleSheet.create({
  overlay: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.45)',
    justifyContent: 'center',
    padding: SPACING.lg
  },
  card: {
    padding: SPACING.lg,
    borderRadius: RADIUS.lg,
    borderWidth: StyleSheet.hairlineWidth
  },
  title: {
    fontSize: 17,
    fontWeight: '700',
    marginBottom: SPACING.sm
  },
  body: {
    fontSize: 13,
    marginBottom: SPACING.lg,
    lineHeight: 18
  }
});
