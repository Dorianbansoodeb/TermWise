import React, { useState } from 'react';
import { ScrollView, StyleSheet, Text, TextInput, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useAppState } from '../state/AppState';
import { useTheme } from '../theme/useTheme';
import { RADIUS, SPACING } from '../theme/tokens';
import { Card } from '../components/Card';
import { PrimaryButton } from '../components/PrimaryButton';
import { formatPercent } from '../utils/format';

const RATE_OPTIONS = [0.05, 0.1, 0.15, 0.2, 0.25];

export function ProfileScreen() {
  const theme = useTheme();
  const {
    settingsForMonth,
    monthlyNote,
    setMonthlyNote,
    setAvailableToBudget,
    setDesiredSavingsRate,
    setSavingsTarget,
    resetToDemo,
    availableToBudget
  } = useAppState();

  const [availableDraft, setAvailableDraft] = useState(`${availableToBudget.toFixed(0)}`);
  const [savingsDraft, setSavingsDraft] = useState(
    settingsForMonth.customSavingsTarget != null
      ? settingsForMonth.customSavingsTarget.toFixed(0)
      : ''
  );

  return (
    <SafeAreaView style={[styles.root, { backgroundColor: theme.background }]} edges={['top']}>
      <ScrollView contentContainerStyle={styles.scroll}>
        <Text style={[styles.title, { color: theme.text }]}>Profile</Text>

        <Card>
          <Text style={[styles.section, { color: theme.text }]}>Monthly Note</Text>
          <Text style={[styles.helper, { color: theme.textMuted }]}>
            Anything to remember this month — coffee budget reminder, upcoming bills, etc.
          </Text>
          <TextInput
            multiline
            value={monthlyNote}
            onChangeText={setMonthlyNote}
            style={[
              styles.textArea,
              {
                color: theme.text,
                borderColor: theme.border,
                backgroundColor: theme.surface
              }
            ]}
            placeholder="Add a quick note..."
            placeholderTextColor={theme.textMuted}
          />
        </Card>

        <Card>
          <Text style={[styles.section, { color: theme.text }]}>Available to Budget</Text>
          <Text style={[styles.helper, { color: theme.textMuted }]}>
            Override how much you've chosen to budget this month. Defaults to recorded income.
          </Text>
          <TextInput
            value={availableDraft}
            onChangeText={setAvailableDraft}
            keyboardType="decimal-pad"
            style={[
              styles.input,
              {
                color: theme.text,
                borderColor: theme.border,
                backgroundColor: theme.surface
              }
            ]}
            placeholder="0"
            placeholderTextColor={theme.textMuted}
          />
          <PrimaryButton
            title="Save Available to Budget"
            onPress={() => {
              const value = parseFloat(availableDraft);
              if (Number.isFinite(value)) setAvailableToBudget(value);
            }}
          />
        </Card>

        <Card>
          <Text style={[styles.section, { color: theme.text }]}>Savings Rate</Text>
          <Text style={[styles.helper, { color: theme.textMuted }]}>
            Default percentage of Available to Budget reserved for savings. A custom dollar amount
            below overrides this rate.
          </Text>
          <View style={styles.rateRow}>
            {RATE_OPTIONS.map((rate) => {
              const selected =
                Math.abs(rate - settingsForMonth.desiredSavingsRate) < 0.001;
              return (
                <PrimaryButton
                  key={rate}
                  title={formatPercent(rate, 0)}
                  variant={selected ? 'primary' : 'secondary'}
                  onPress={() => setDesiredSavingsRate(rate)}
                  style={{ flex: 1 }}
                />
              );
            })}
          </View>
          <Text style={[styles.helper, { color: theme.textMuted, marginTop: SPACING.sm }]}>
            Custom dollar savings target (optional)
          </Text>
          <TextInput
            value={savingsDraft}
            onChangeText={setSavingsDraft}
            keyboardType="decimal-pad"
            style={[
              styles.input,
              {
                color: theme.text,
                borderColor: theme.border,
                backgroundColor: theme.surface
              }
            ]}
            placeholder="Leave blank to use rate"
            placeholderTextColor={theme.textMuted}
          />
          <View style={styles.rateRow}>
            <PrimaryButton
              title="Save Custom Target"
              variant="primary"
              style={{ flex: 1 }}
              onPress={() => {
                const trimmed = savingsDraft.trim();
                if (trimmed === '') {
                  setSavingsTarget(undefined);
                  return;
                }
                const value = parseFloat(trimmed);
                if (Number.isFinite(value)) setSavingsTarget(value);
              }}
            />
            <PrimaryButton
              title="Clear"
              variant="ghost"
              style={{ flex: 1 }}
              onPress={() => {
                setSavingsDraft('');
                setSavingsTarget(undefined);
              }}
            />
          </View>
        </Card>

        <Card>
          <Text style={[styles.section, { color: theme.text }]}>Data</Text>
          <Text style={[styles.helper, { color: theme.textMuted }]}>
            Reset the local snapshot to the bundled student demo. This clears AsyncStorage.
          </Text>
          <PrimaryButton title="Reset to Demo Data" variant="danger" onPress={resetToDemo} />
        </Card>
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  root: {
    flex: 1
  },
  scroll: {
    padding: SPACING.lg,
    gap: SPACING.lg
  },
  title: {
    fontSize: 26,
    fontWeight: '800'
  },
  section: {
    fontSize: 16,
    fontWeight: '700'
  },
  helper: {
    fontSize: 12,
    marginTop: 2,
    marginBottom: SPACING.sm
  },
  input: {
    borderRadius: RADIUS.md,
    borderWidth: StyleSheet.hairlineWidth,
    paddingHorizontal: SPACING.md,
    paddingVertical: SPACING.sm + 2,
    marginBottom: SPACING.sm,
    fontSize: 15
  },
  textArea: {
    borderRadius: RADIUS.md,
    borderWidth: StyleSheet.hairlineWidth,
    paddingHorizontal: SPACING.md,
    paddingVertical: SPACING.sm,
    minHeight: 80,
    textAlignVertical: 'top',
    fontSize: 14
  },
  rateRow: {
    flexDirection: 'row',
    gap: SPACING.sm
  }
});
