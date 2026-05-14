import React from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useTheme } from '../theme/useTheme';
import { SPACING } from '../theme/tokens';
import {
  BOTTOM_NAV_BOTTOM_GAP,
  BOTTOM_NAV_HORIZONTAL_INSET,
  FAB_QUICK_ADD_MARGIN_LEFT,
  FAB_QUICK_ADD_SIZE,
  PILL_TAB_BAR_BORDER_RADIUS,
  PILL_TAB_BAR_HEIGHT,
  PILL_TAB_MARGIN_RIGHT,
  type TabRoute
} from './constants';

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

/// Bottom navigation: left = pill with four tabs only; right = separate orange
/// Quick Add FAB. The FAB is never a child of the pill so it cannot overlap Profile.
export function TabBar({ active, onSelect, onQuickAdd }: TabBarProps) {
  const theme = useTheme();
  const insets = useSafeAreaInsets();

  return (
    <View
      style={[
        styles.bottomNavWrapper,
        {
          left: BOTTOM_NAV_HORIZONTAL_INSET,
          right: BOTTOM_NAV_HORIZONTAL_INSET,
          bottom: insets.bottom + BOTTOM_NAV_BOTTOM_GAP
        }
      ]}
    >
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
            opacity: pressed ? 0.85 : 1,
            marginLeft: FAB_QUICK_ADD_MARGIN_LEFT
          }
        ]}
      >
        <Text style={[styles.fabPlus, { color: theme.primaryText }]}>+</Text>
      </Pressable>
    </View>
  );
}

const styles = StyleSheet.create({
  bottomNavWrapper: {
    position: 'absolute',
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between'
  },
  pill: {
    flex: 1,
    flexDirection: 'row',
    height: PILL_TAB_BAR_HEIGHT,
    borderRadius: PILL_TAB_BAR_BORDER_RADIUS,
    marginRight: PILL_TAB_MARGIN_RIGHT,
    paddingHorizontal: 8,
    alignItems: 'center',
    justifyContent: 'space-around',
    borderWidth: StyleSheet.hairlineWidth,
    shadowOffset: { width: 0, height: 6 },
    shadowOpacity: 0.08,
    shadowRadius: 12,
    elevation: 8
  },
  item: {
    flex: 1,
    height: '100%',
    alignItems: 'center',
    justifyContent: 'center',
    borderRadius: PILL_TAB_BAR_BORDER_RADIUS / 2,
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
    width: FAB_QUICK_ADD_SIZE,
    height: FAB_QUICK_ADD_SIZE,
    borderRadius: FAB_QUICK_ADD_SIZE / 2,
    alignItems: 'center',
    justifyContent: 'center',
    flexShrink: 0,
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.2,
    shadowRadius: 10,
    elevation: 10
  },
  fabPlus: {
    fontSize: 34,
    lineHeight: 36,
    fontWeight: '600'
  }
});
