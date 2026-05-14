import React from 'react';
import { ScrollView, StyleSheet, Text, TextInput, View } from 'react-native';
import { SafeAreaView, useSafeAreaInsets } from 'react-native-safe-area-context';
import { useAppState } from '../state/AppState';
import { useTheme } from '../theme/useTheme';
import { RADIUS, SPACING } from '../theme/tokens';
import { contentBottomPaddingForTabs } from '../navigation/constants';
import { Card } from '../components/Card';
import { PillBadge } from '../components/PillBadge';

export function ProfileScreen() {
  const theme = useTheme();
  const insets = useSafeAreaInsets();
  const { monthlyNote, setMonthlyNote } = useAppState();

  return (
    <SafeAreaView style={[styles.root, { backgroundColor: theme.background }]} edges={['top']}>
      <ScrollView
        contentContainerStyle={[
          styles.scroll,
          { paddingBottom: contentBottomPaddingForTabs(insets.bottom) }
        ]}
        showsVerticalScrollIndicator={false}
      >
        <Text style={[styles.title, { color: theme.text }]}>Profile</Text>
        <Text style={[styles.subtitle, { color: theme.textMuted }]}>
          Monthly note and app settings. Budget planning lives on the Budget tab.
        </Text>

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

        <PlaceholderCard
          title="Account"
          helper="Sign in and manage your profile when cloud sync is available."
        />
        <PlaceholderCard
          title="Currency"
          helper="Display currency and formatting preferences."
        />
        <PlaceholderCard
          title="App settings"
          helper="Theme, notifications, and other preferences."
        />
        <PlaceholderCard
          title="Import / Export"
          helper="Back up or restore your local data."
        />
        <PlaceholderCard
          title="Privacy & security"
          helper="Data controls and security options."
        />
      </ScrollView>
    </SafeAreaView>
  );
}

function PlaceholderCard({ title, helper }: { title: string; helper: string }) {
  const theme = useTheme();
  return (
    <Card>
      <View style={styles.placeholderHeader}>
        <Text style={[styles.section, { color: theme.text }]}>{title}</Text>
        <PillBadge label="Coming soon" tone="neutral" />
      </View>
      <Text style={[styles.helper, { color: theme.textMuted, marginBottom: 0 }]}>{helper}</Text>
    </Card>
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
  subtitle: {
    fontSize: 12,
    marginTop: -SPACING.sm
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
  textArea: {
    borderRadius: RADIUS.md,
    borderWidth: StyleSheet.hairlineWidth,
    paddingHorizontal: SPACING.md,
    paddingVertical: SPACING.sm,
    minHeight: 80,
    textAlignVertical: 'top',
    fontSize: 14
  },
  placeholderHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginBottom: SPACING.xs
  }
});
