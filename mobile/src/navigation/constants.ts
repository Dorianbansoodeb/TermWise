/** @deprecated Use PILL_TAB_BAR_HEIGHT — kept for any stale imports */
export const TAB_BAR_HEIGHT = 78;

export const TAB_ROUTES = ['Dashboard', 'Transactions', 'Budget', 'Profile'] as const;
export type TabRoute = (typeof TAB_ROUTES)[number];

export type RootStackParamList = {
  Tabs: undefined;
  QuickAdd: undefined;
};

// Bottom nav layout (pill + separate FAB). Used by TabBar, UndoSnackbar, and
// tab screen scroll clearance.

export const BOTTOM_NAV_HORIZONTAL_INSET = 20;
export const BOTTOM_NAV_BOTTOM_GAP = 0;
export const PILL_TAB_BAR_HEIGHT = 78;
export const PILL_TAB_BAR_BORDER_RADIUS = 39;
export const PILL_TAB_MARGIN_RIGHT = 14;
export const FAB_QUICK_ADD_SIZE = 72;
export const FAB_QUICK_ADD_MARGIN_LEFT = 12;
/** Extra scroll breathing room below the nav row */
export const CONTENT_NAV_EXTRA_PADDING = 32;

/// Distance from the physical bottom of the screen to the top of the nav row
/// (safe area + gap + pill height — pill is the taller of the two siblings).
export function bottomNavReservedHeight(safeAreaBottom: number): number {
  return safeAreaBottom + BOTTOM_NAV_BOTTOM_GAP + PILL_TAB_BAR_HEIGHT;
}

/// `paddingBottom` for tab bodies / scroll content so nothing hides under the nav.
export function contentBottomPaddingForTabs(safeAreaBottom: number): number {
  return bottomNavReservedHeight(safeAreaBottom) + CONTENT_NAV_EXTRA_PADDING;
}
