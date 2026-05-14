import React from 'react';
import { Platform, Pressable, StyleSheet, Text, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useTheme } from '../theme/useTheme';
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
  { route: 'Transactions', label: 'Transactions', icon: '\u2630' },
  { route: 'Budget', label: 'Budget', icon: '\u25BC' },
  { route: 'Profile', label: 'Profile', icon: '\u263A' }
];

/// SwiftUI-style bottom nav: wide pill with padded tab cells, rounded capsule
/// highlight on the selected tab (icon + label orange), inactive tabs gray.
/// Orange Quick Add FAB sits outside the pill with a clear gap — no overlap.
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
              accessibilityRole="tab"
              accessibilityState={{ selected: isActive }}
              style={styles.tabPressable}
            >
              <View
                style={[
                  styles.tabInner,
                  isActive && {
                    backgroundColor: theme.surfaceMuted,
                    ...styles.tabInnerActive
                  }
                ]}
              >
                <Text
                  style={[
                    styles.tabIcon,
                    { color: isActive ? theme.primary : theme.textMuted }
                  ]}
                >
                  {item.icon}
                </Text>
                <Text
                  style={[
                    styles.tabLabel,
                    {
                      color: isActive ? theme.primary : theme.textMuted,
                      fontWeight: isActive ? '700' : '500'
                    }
                  ]}
                  numberOfLines={1}
                  adjustsFontSizeToFit={Platform.OS === 'ios'}
                  minimumFontScale={0.82}
                >
                  {item.label}
                </Text>
              </View>
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
    paddingHorizontal: 12,
    paddingVertical: 9,
    alignItems: 'center',
    justifyContent: 'space-around',
    borderWidth: StyleSheet.hairlineWidth,
    minWidth: 0,
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.07,
    shadowRadius: 14,
    elevation: 8
  },
  tabPressable: {
    flex: 1,
    minWidth: 0,
    height: '100%',
    alignItems: 'center',
    justifyContent: 'center'
  },
  tabInner: {
    width: '100%',
    maxWidth: '100%',
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 6,
    paddingHorizontal: 4,
    borderRadius: 32
  },
  tabInnerActive: {
    minHeight: 58,
    minWidth: 72,
    paddingVertical: 8,
    paddingHorizontal: 8
  },
  tabIcon: {
    fontSize: 20,
    lineHeight: 22,
    textAlign: 'center'
  },
  tabLabel: {
    fontSize: 11,
    marginTop: 4,
    textAlign: 'center',
    letterSpacing: -0.15
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
    fontSize: 32,
    lineHeight: 34,
    fontWeight: '600'
  }
});
