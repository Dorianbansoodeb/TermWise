import React from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useTheme } from '../theme/useTheme';
import { RADIUS, SPACING } from '../theme/tokens';
import { TAB_BAR_HEIGHT, type TabRoute } from './constants';

interface TabBarProps {
  active: TabRoute;
  onSelect: (route: TabRoute) => void;
  onQuickAdd: () => void;
}

const ITEMS: { route: TabRoute; label: string; icon: string }[] = [
  { route: 'Dashboard', label: 'Home', icon: '\u2302' },
  { route: 'Transactions', label: 'Txns', icon: '\u2630' },
  { route: 'Budget', label: 'Budget', icon: '\u25BC' },
  { route: 'Profile', label: 'Profile', icon: '\u263A' }
];

/// Custom pill-shaped bottom nav with an orange circular Quick Add FAB above.
/// Matches the SwiftUI `CustomBottomNav` + floating action button design.
export function TabBar({ active, onSelect, onQuickAdd }: TabBarProps) {
  const theme = useTheme();
  const insets = useSafeAreaInsets();
  return (
    <View style={[styles.wrapper, { paddingBottom: Math.max(insets.bottom, SPACING.sm) }]}>
      <View
        style={[
          styles.pill,
          {
            backgroundColor: theme.surface,
            borderColor: theme.border,
            shadowColor: theme.text
          }
        ]}
      >
        {ITEMS.map((item) => {
          const isActive = item.route === active;
          return (
            <Pressable
              key={item.route}
              onPress={() => onSelect(item.route)}
              hitSlop={4}
              style={[styles.item, isActive && { backgroundColor: theme.surfaceMuted }]}
            >
              <Text
                style={[
                  styles.icon,
                  { color: isActive ? theme.primary : theme.textMuted }
                ]}
              >
                {item.icon}
              </Text>
              <Text
                style={[
                  styles.label,
                  {
                    color: isActive ? theme.text : theme.textMuted,
                    fontWeight: isActive ? '700' : '500'
                  }
                ]}
                numberOfLines={1}
              >
                {item.label}
              </Text>
            </Pressable>
          );
        })}
      </View>

      <Pressable
        onPress={onQuickAdd}
        accessibilityLabel="Quick add transaction"
        style={({ pressed }) => [
          styles.fab,
          {
            backgroundColor: theme.primary,
            shadowColor: theme.text,
            opacity: pressed ? 0.85 : 1
          }
        ]}
      >
        <Text style={[styles.fabPlus, { color: theme.primaryText }]}>+</Text>
      </Pressable>
    </View>
  );
}

const styles = StyleSheet.create({
  wrapper: {
    paddingHorizontal: SPACING.lg,
    paddingTop: SPACING.sm,
    alignItems: 'center'
  },
  pill: {
    flexDirection: 'row',
    height: TAB_BAR_HEIGHT,
    paddingHorizontal: SPACING.sm,
    paddingVertical: SPACING.xs,
    borderRadius: RADIUS.pill,
    borderWidth: StyleSheet.hairlineWidth,
    width: '100%',
    alignItems: 'center',
    shadowOffset: { width: 0, height: 6 },
    shadowOpacity: 0.06,
    shadowRadius: 12,
    elevation: 6
  },
  item: {
    flex: 1,
    height: '100%',
    alignItems: 'center',
    justifyContent: 'center',
    borderRadius: RADIUS.pill,
    paddingHorizontal: SPACING.xs
  },
  icon: {
    fontSize: 18,
    lineHeight: 20
  },
  label: {
    fontSize: 10,
    marginTop: 2
  },
  fab: {
    position: 'absolute',
    top: -28,
    right: SPACING.lg,
    width: 56,
    height: 56,
    borderRadius: 28,
    alignItems: 'center',
    justifyContent: 'center',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.18,
    shadowRadius: 12,
    elevation: 6
  },
  fabPlus: {
    fontSize: 28,
    lineHeight: 30,
    fontWeight: '600'
  }
});
