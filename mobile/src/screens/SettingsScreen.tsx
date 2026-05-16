import React, { useMemo, useState } from 'react';
import {
  Alert,
  Pressable,
  ScrollView,
  StyleSheet,
  Switch,
  Text,
  TextInput,
  View
} from 'react-native';
import { SafeAreaView, useSafeAreaInsets } from 'react-native-safe-area-context';
import type { NativeStackScreenProps } from '@react-navigation/native-stack';
import Constants from 'expo-constants';
import { useAppState } from '../state/AppState';
import { useTheme } from '../theme/useTheme';
import { RADIUS, SPACING } from '../theme/tokens';
import type { RootStackParamList } from '../navigation/constants';
import type {
  BudgetWarningThresholdPercent,
  SupportedCurrency,
  ThemePreference
} from '../types/models';
import { Card } from '../components/Card';
import { PrimaryButton } from '../components/PrimaryButton';
import { PillBadge } from '../components/PillBadge';
import { convertCurrency } from '../utils/currencyConverter';
import { formatCurrencyWith } from '../utils/format';

const THEME_OPTIONS: ThemePreference[] = ['system', 'light', 'dark'];
const CURRENCIES: SupportedCurrency[] = ['CAD', 'USD', 'EUR', 'GBP'];
const THRESHOLDS: BudgetWarningThresholdPercent[] = [75, 90, 100];

type Props = NativeStackScreenProps<RootStackParamList, 'Settings'>;

export function SettingsScreen(_props: Props) {
  const theme = useTheme();
  const insets = useSafeAreaInsets();
  const {
    appUserSettings,
    updateAppUserSettings,
    resetToDemo,
    formatMoney
  } = useAppState();

  const [converterAmount, setConverterAmount] = useState('100');
  const [converterFrom, setConverterFrom] = useState<SupportedCurrency>('USD');
  const [converterTo, setConverterTo] = useState<SupportedCurrency>('CAD');

  const converted = useMemo(() => {
    const n = parseFloat(converterAmount.replace(/,/g, ''));
    if (!Number.isFinite(n)) return null;
    return convertCurrency(n, converterFrom, converterTo);
  }, [converterAmount, converterFrom, converterTo]);

  const appVersion =
    Constants.expoConfig?.version ?? Constants.nativeAppVersion ?? '0.1.0';

  const onResetDemo = () => {
    Alert.alert(
      'Reset demo data?',
      'This replaces your local budget and transactions with the built-in demo snapshot.',
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Reset',
          style: 'destructive',
          onPress: async () => {
            await resetToDemo();
          }
        }
      ]
    );
  };

  return (
    <SafeAreaView style={[styles.root, { backgroundColor: theme.background }]} edges={['bottom']}>
      <ScrollView
        contentContainerStyle={[
          styles.scroll,
          { paddingBottom: Math.max(insets.bottom, SPACING.lg) + SPACING.md }
        ]}
        showsVerticalScrollIndicator={false}
      >
        <SectionTitle theme={theme} title="Appearance" />
        <Card>
          <Text style={[styles.helper, { color: theme.textMuted }]}>
            Theme applies across the app. System follows your device light/dark mode.
          </Text>
          <View style={styles.rowGap}>
            {THEME_OPTIONS.map((opt) => (
              <ChoiceRow
                key={opt}
                label={opt === 'system' ? 'System' : opt === 'light' ? 'Light' : 'Dark'}
                selected={appUserSettings.themePreference === opt}
                onPress={() => updateAppUserSettings({ themePreference: opt })}
                theme={theme}
              />
            ))}
          </View>
        </Card>

        <SectionTitle theme={theme} title="Currency" />
        <Card>
          <Text style={[styles.subhead, { color: theme.text }]}>Default currency</Text>
          <Text style={[styles.helper, { color: theme.textMuted }]}>
            Used when displaying amounts in the app (budget, transactions, charts).
          </Text>
          <View style={styles.rowGap}>
            {CURRENCIES.map((c) => (
              <ChoiceRow
                key={c}
                label={c}
                selected={appUserSettings.defaultCurrency === c}
                onPress={() => updateAppUserSettings({ defaultCurrency: c })}
                theme={theme}
              />
            ))}
          </View>
          <Text style={[styles.preview, { color: theme.textMuted }]}>
            Preview: {formatMoney(1234.56, { compact: true })} / {formatMoney(1234.56)}
          </Text>
        </Card>

        <Card>
          <Text style={[styles.subhead, { color: theme.text }]}>Currency converter</Text>
          {/* TODO: Wire live exchange rates (free tier or user API key). Static rates for now. */}
          <Text style={[styles.helper, { color: theme.textMuted }]}>
            Approximate conversion using built-in sample rates — not for trading decisions.
          </Text>
          <TextInput
            value={converterAmount}
            onChangeText={setConverterAmount}
            keyboardType="decimal-pad"
            placeholder="Amount"
            placeholderTextColor={theme.textMuted}
            style={[
              styles.input,
              { color: theme.text, borderColor: theme.border, backgroundColor: theme.surface }
            ]}
          />
          <Text style={[styles.miniLabel, { color: theme.textMuted }]}>From</Text>
          <View style={styles.inlineChoices}>
            {CURRENCIES.map((c) => (
              <MiniChip
                key={`f-${c}`}
                label={c}
                selected={converterFrom === c}
                onPress={() => setConverterFrom(c)}
                theme={theme}
              />
            ))}
          </View>
          <Text style={[styles.miniLabel, { color: theme.textMuted }]}>To</Text>
          <View style={styles.inlineChoices}>
            {CURRENCIES.map((c) => (
              <MiniChip
                key={`t-${c}`}
                label={c}
                selected={converterTo === c}
                onPress={() => setConverterTo(c)}
                theme={theme}
              />
            ))}
          </View>
          <Text style={[styles.converted, { color: theme.text }]}>
            {converted == null
              ? '—'
              : formatCurrencyWith(converted, converterTo, { compact: false })}
          </Text>
        </Card>

        <SectionTitle theme={theme} title="Budget preferences" />
        <Card>
          <Text style={[styles.subhead, { color: theme.text }]}>Month start</Text>
          <Text style={[styles.helper, { color: theme.textMuted }]}>
            Calendar month starting on the 1st (default). Custom start days will be supported later.
          </Text>
          {/* TODO: Honor custom month start in date windows / rollover when budget engine supports it. */}
          <ChoiceRow
            label="1st of month"
            selected={appUserSettings.monthStartDay === 1}
            onPress={() => updateAppUserSettings({ monthStartDay: 1 })}
            theme={theme}
          />
        </Card>
        <Card>
          <Text style={[styles.subhead, { color: theme.text }]}>Budget warning threshold</Text>
          <Text style={[styles.helper, { color: theme.textMuted }]}>
            Saved locally for future use when we surface %‑of‑limit warnings in the app.
          </Text>
          {/* TODO: Connect to dashboard / pace UI when threshold-driven warnings ship. */}
          <View style={styles.inlineChoices}>
            {THRESHOLDS.map((pct) => (
              <MiniChip
                key={pct}
                label={`${pct}%`}
                selected={appUserSettings.budgetWarningThresholdPercent === pct}
                onPress={() => updateAppUserSettings({ budgetWarningThresholdPercent: pct })}
                theme={theme}
              />
            ))}
          </View>
        </Card>

        <SectionTitle theme={theme} title="Notifications" />
        <Card>
          <Text style={[styles.helper, { color: theme.textMuted }]}>
            Toggles are saved locally only — no reminders are sent yet.
          </Text>
          {/* TODO: Push notifications + local scheduling when backend / OS permissions are ready. */}
          <ToggleRow
            label="Bill due reminders"
            value={appUserSettings.billDueRemindersEnabled}
            onValueChange={(v) => updateAppUserSettings({ billDueRemindersEnabled: v })}
            theme={theme}
          />
          <ToggleRow
            label="Budget warning reminders"
            value={appUserSettings.budgetWarningRemindersEnabled}
            onValueChange={(v) => updateAppUserSettings({ budgetWarningRemindersEnabled: v })}
            theme={theme}
          />
          <ToggleRow
            label="Weekly spending summary"
            value={appUserSettings.weeklySpendingSummaryEnabled}
            onValueChange={(v) => updateAppUserSettings({ weeklySpendingSummaryEnabled: v })}
            theme={theme}
          />
        </Card>

        <SectionTitle theme={theme} title="Data" />
        <Card>
          <PrimaryButton title="Reset demo data" variant="danger" onPress={onResetDemo} />
          <Text style={[styles.helper, { color: theme.textMuted, marginTop: SPACING.sm }]}>
            Replaces local transactions and budget with the demo seed. Your Settings choices above
            are kept.
          </Text>
          <Pressable
            style={[styles.placeholderBtn, { borderColor: theme.border }]}
            disabled
            onPress={() => {}}
          >
            <Text style={[styles.placeholderBtnText, { color: theme.textMuted }]}>Export data</Text>
            <PillBadge label="Soon" tone="neutral" />
          </Pressable>
          <Pressable
            style={[styles.placeholderBtn, { borderColor: theme.border, marginTop: SPACING.sm }]}
            disabled
            onPress={() => {}}
          >
            <Text style={[styles.placeholderBtnText, { color: theme.textMuted }]}>Import data</Text>
            <PillBadge label="Soon" tone="neutral" />
          </Pressable>
        </Card>

        <SectionTitle theme={theme} title="Account & security" />
        <Card>
          <Text style={[styles.body, { color: theme.text }]}>
            Sign in with Apple / Google — planned. Auth0-backed accounts and MongoDB sync — planned.
            This build stores everything on-device only.
          </Text>
          {/* TODO: Auth0, Sign in with Apple / Google, encrypted cloud sync. */}
        </Card>

        <SectionTitle theme={theme} title="About" />
        <Card>
          <Text style={[styles.appName, { color: theme.text }]}>TermWise</Text>
          <Text style={[styles.version, { color: theme.textMuted }]}>Version {appVersion}</Text>
          <Text style={[styles.body, { color: theme.text, marginTop: SPACING.sm }]}>
            Student budgeting app for income, bills, spending, and savings planning.
          </Text>
          {/* TODO: Replace with public repository URL when open-sourced. */}
          <Text style={[styles.version, { color: theme.textMuted, marginTop: SPACING.md }]}>
            GitHub link — add your repo URL later.
          </Text>
        </Card>
      </ScrollView>
    </SafeAreaView>
  );
}

function SectionTitle({ title, theme }: { title: string; theme: ReturnType<typeof useTheme> }) {
  return (
    <Text style={[styles.sectionTitle, { color: theme.textMuted }]} accessibilityRole="header">
      {title.toUpperCase()}
    </Text>
  );
}

function ChoiceRow({
  label,
  selected,
  onPress,
  theme
}: {
  label: string;
  selected: boolean;
  onPress: () => void;
  theme: ReturnType<typeof useTheme>;
}) {
  return (
    <Pressable
      onPress={onPress}
      style={({ pressed }) => [
        styles.choice,
        {
          borderColor: selected ? theme.primary : theme.border,
          backgroundColor: selected ? theme.surfaceMuted : theme.surface,
          opacity: pressed ? 0.85 : 1
        }
      ]}
    >
      <Text style={[styles.choiceLabel, { color: theme.text }]}>{label}</Text>
      {selected ? (
        <Text style={{ color: theme.primary, fontWeight: '800', fontSize: 14 }}>✓</Text>
      ) : null}
    </Pressable>
  );
}

function MiniChip({
  label,
  selected,
  onPress,
  theme
}: {
  label: string;
  selected: boolean;
  onPress: () => void;
  theme: ReturnType<typeof useTheme>;
}) {
  return (
    <Pressable
      onPress={onPress}
      style={[
        styles.chip,
        {
          borderColor: selected ? theme.primary : theme.border,
          backgroundColor: selected ? theme.surfaceMuted : theme.surface
        }
      ]}
    >
      <Text style={[styles.chipLabel, { color: theme.text }]}>{label}</Text>
    </Pressable>
  );
}

function ToggleRow({
  label,
  value,
  onValueChange,
  theme
}: {
  label: string;
  value: boolean;
  onValueChange: (v: boolean) => void;
  theme: ReturnType<typeof useTheme>;
}) {
  return (
    <View style={styles.toggleRow}>
      <Text style={[styles.toggleLabel, { color: theme.text }]}>{label}</Text>
      <Switch
        value={value}
        onValueChange={onValueChange}
        trackColor={{ false: theme.border, true: theme.primary }}
        thumbColor={theme.surface}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  root: {
    flex: 1
  },
  scroll: {
    padding: SPACING.lg,
    gap: SPACING.md
  },
  sectionTitle: {
    fontSize: 11,
    fontWeight: '700',
    letterSpacing: 0.6,
    marginBottom: 2
  },
  helper: {
    fontSize: 12,
    lineHeight: 16,
    marginBottom: SPACING.sm
  },
  subhead: {
    fontSize: 15,
    fontWeight: '700',
    marginBottom: SPACING.xs
  },
  rowGap: {
    gap: SPACING.sm
  },
  choice: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingVertical: SPACING.sm,
    paddingHorizontal: SPACING.md,
    borderRadius: RADIUS.md,
    borderWidth: StyleSheet.hairlineWidth
  },
  choiceLabel: {
    fontSize: 14,
    fontWeight: '600'
  },
  preview: {
    fontSize: 12,
    marginTop: SPACING.sm
  },
  input: {
    borderWidth: StyleSheet.hairlineWidth,
    borderRadius: RADIUS.md,
    paddingHorizontal: SPACING.md,
    paddingVertical: SPACING.sm,
    fontSize: 16,
    marginBottom: SPACING.sm
  },
  miniLabel: {
    fontSize: 11,
    fontWeight: '600',
    marginBottom: SPACING.xs
  },
  inlineChoices: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: SPACING.xs,
    marginBottom: SPACING.sm
  },
  chip: {
    paddingVertical: 6,
    paddingHorizontal: SPACING.sm,
    borderRadius: RADIUS.pill,
    borderWidth: StyleSheet.hairlineWidth
  },
  chipLabel: {
    fontSize: 12,
    fontWeight: '600'
  },
  converted: {
    fontSize: 18,
    fontWeight: '800',
    marginTop: SPACING.xs
  },
  toggleRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingVertical: SPACING.sm,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: 'rgba(128,128,128,0.15)'
  },
  toggleLabel: {
    fontSize: 14,
    flex: 1,
    paddingRight: SPACING.md
  },
  placeholderBtn: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingVertical: SPACING.md,
    paddingHorizontal: SPACING.md,
    borderRadius: RADIUS.md,
    borderWidth: StyleSheet.hairlineWidth,
    opacity: 0.65
  },
  placeholderBtnText: {
    fontSize: 14,
    fontWeight: '600'
  },
  body: {
    fontSize: 14,
    lineHeight: 20
  },
  appName: {
    fontSize: 22,
    fontWeight: '800'
  },
  version: {
    fontSize: 12,
    marginTop: 4
  }
});
