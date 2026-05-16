import React, { useMemo } from 'react';
import { Pressable, ScrollView, StyleSheet, Text, TextInput, View } from 'react-native';
import { SafeAreaView, useSafeAreaInsets } from 'react-native-safe-area-context';
import { useNavigation } from '@react-navigation/native';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { useAppState } from '../state/AppState';
import { useTheme } from '../theme/useTheme';
import { RADIUS, SPACING } from '../theme/tokens';
import { contentBottomPaddingForTabs, type RootStackParamList } from '../navigation/constants';
import { Card } from '../components/Card';
import { ProfilePastMonthsCard } from '../components/ProfilePastMonthsCard';
import { profileMonthSummaries } from '../utils/financeCalculator';

export function ProfileScreen() {
  const theme = useTheme();
  const insets = useSafeAreaInsets();
  const navigation = useNavigation<NativeStackNavigationProp<RootStackParamList>>();
  const {
    monthlyNote,
    setMonthlyNote,
    monthlyNotes,
    setMonthlyNoteForMonth,
    transactions,
    budgetItems,
    referenceDate
  } = useAppState();

  const pastMonthSummaries = useMemo(
    () => profileMonthSummaries(transactions, budgetItems, referenceDate, 5),
    [transactions, budgetItems, referenceDate]
  );

  return (
    <SafeAreaView style={[styles.root, { backgroundColor: theme.background }]} edges={['top']}>
      <View style={[styles.headerBar, { paddingHorizontal: SPACING.lg, paddingTop: SPACING.xs }]}>
        <View style={styles.headerRow}>
          <Text style={[styles.title, { color: theme.text }]}>Profile</Text>
          <Pressable
            onPress={() => navigation.navigate('Settings')}
            accessibilityRole="button"
            accessibilityLabel="Open settings"
            hitSlop={12}
            style={({ pressed }) => [
              styles.settingsIconWrap,
              {
                borderColor: theme.border,
                backgroundColor: theme.surfaceMuted,
                opacity: pressed ? 0.75 : 1
              }
            ]}
          >
            <Text style={[styles.settingsIcon, { color: theme.primary }]}>⚙</Text>
          </Pressable>
        </View>
        <Text style={[styles.subtitle, { color: theme.textMuted }]}>
          Past month budgets and your monthly note. Planning lives on the Budget tab.
        </Text>
      </View>
      <ScrollView
        contentContainerStyle={[
          styles.scroll,
          { paddingBottom: contentBottomPaddingForTabs(insets.bottom) }
        ]}
        showsVerticalScrollIndicator={false}
      >
        <ProfilePastMonthsCard
          summaries={pastMonthSummaries}
          budgetItems={budgetItems}
          monthlyNotes={monthlyNotes}
          onSetNoteForMonth={setMonthlyNoteForMonth}
        />

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
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  root: {
    flex: 1
  },
  headerBar: {
    paddingBottom: SPACING.sm
  },
  scroll: {
    paddingHorizontal: SPACING.lg,
    paddingTop: 0,
    gap: SPACING.lg
  },
  headerRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    gap: SPACING.md
  },
  title: {
    flex: 1,
    fontSize: 26,
    fontWeight: '800'
  },
  subtitle: {
    fontSize: 12,
    marginTop: SPACING.sm
  },
  settingsIconWrap: {
    width: 40,
    height: 40,
    borderRadius: RADIUS.md,
    borderWidth: StyleSheet.hairlineWidth,
    alignItems: 'center',
    justifyContent: 'center'
  },
  settingsIcon: {
    fontSize: 22,
    lineHeight: 24,
    textAlign: 'center'
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
  }
});
