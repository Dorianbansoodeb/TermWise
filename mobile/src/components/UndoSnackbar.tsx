import React from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useAppState } from '../state/AppState';
import { useTheme } from '../theme/useTheme';
import { RADIUS, SPACING } from '../theme/tokens';
import { bottomNavReservedHeight } from '../navigation/constants';

/// Auto-dismissing undo snackbar. Sits above the pill + FAB row using
/// `bottomNavReservedHeight` so it clears the taller 78pt pill and the safe-area gap.
export function UndoSnackbar() {
  const { pendingUndoBar, dismissUndoBar } = useAppState();
  const theme = useTheme();
  const insets = useSafeAreaInsets();
  if (!pendingUndoBar) return null;
  return (
    <View
      pointerEvents="box-none"
      style={[
        styles.wrapper,
        { paddingBottom: bottomNavReservedHeight(insets.bottom) + SPACING.md }
      ]}
    >
      <View
        style={[
          styles.bar,
          { backgroundColor: theme.text, borderColor: theme.text }
        ]}
      >
        <Text style={[styles.label, { color: theme.textInverse }]} numberOfLines={1}>
          {pendingUndoBar.message}
        </Text>
        <Pressable
          onPress={() => dismissUndoBar({ performAction: true })}
          hitSlop={8}
          style={({ pressed }) => [styles.undoButton, pressed && { opacity: 0.6 }]}
        >
          <Text style={[styles.undoText, { color: theme.primary }]}>Undo</Text>
        </Pressable>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  wrapper: {
    position: 'absolute',
    bottom: 0,
    left: 0,
    right: 0,
    alignItems: 'center'
  },
  bar: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: SPACING.sm + 2,
    paddingHorizontal: SPACING.lg,
    borderRadius: RADIUS.pill,
    borderWidth: StyleSheet.hairlineWidth,
    minWidth: 240,
    maxWidth: 360
  },
  label: {
    flex: 1,
    fontSize: 13,
    fontWeight: '600'
  },
  undoButton: {
    paddingHorizontal: SPACING.sm,
    paddingVertical: 4
  },
  undoText: {
    fontSize: 13,
    fontWeight: '700'
  }
});
