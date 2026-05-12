export const TAB_BAR_HEIGHT = 64;

export const TAB_ROUTES = ['Dashboard', 'Transactions', 'Budget', 'Profile'] as const;
export type TabRoute = (typeof TAB_ROUTES)[number];

export type RootStackParamList = {
  Tabs: undefined;
  QuickAdd: undefined;
};
