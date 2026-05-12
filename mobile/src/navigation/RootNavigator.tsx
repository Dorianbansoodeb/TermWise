import React, { useState } from 'react';
import { StyleSheet, View } from 'react-native';
import { NavigationContainer, DefaultTheme, DarkTheme } from '@react-navigation/native';
import {
  createNativeStackNavigator,
  type NativeStackScreenProps
} from '@react-navigation/native-stack';
import { useTheme } from '../theme/useTheme';
import { useAppState } from '../state/AppState';
import { DashboardScreen } from '../screens/DashboardScreen';
import { TransactionsScreen } from '../screens/TransactionsScreen';
import { BudgetScreen } from '../screens/BudgetScreen';
import { ProfileScreen } from '../screens/ProfileScreen';
import { QuickAddScreen } from '../screens/QuickAddScreen';
import { IncomePromptDialog } from '../components/IncomePromptDialog';
import { UndoSnackbar } from '../components/UndoSnackbar';
import { TabBar } from './TabBar';
import { TAB_BAR_HEIGHT, type RootStackParamList, type TabRoute } from './constants';

const RootStack = createNativeStackNavigator<RootStackParamList>();

export function RootNavigator() {
  const theme = useTheme();
  const navTheme = {
    ...(theme.scheme === 'dark' ? DarkTheme : DefaultTheme),
    colors: {
      ...(theme.scheme === 'dark' ? DarkTheme.colors : DefaultTheme.colors),
      background: theme.background,
      card: theme.surface,
      text: theme.text,
      border: theme.border,
      primary: theme.primary
    }
  };
  return (
    <NavigationContainer theme={navTheme}>
      <RootStack.Navigator
        screenOptions={{
          headerShown: false,
          contentStyle: { backgroundColor: theme.background }
        }}
      >
        <RootStack.Screen name="Tabs" component={TabsRoot} />
        <RootStack.Screen
          name="QuickAdd"
          component={QuickAddScreen}
          options={{
            presentation: 'modal',
            animation: 'slide_from_bottom'
          }}
        />
      </RootStack.Navigator>
    </NavigationContainer>
  );
}

type TabsRootProps = NativeStackScreenProps<RootStackParamList, 'Tabs'>;

function TabsRoot({ navigation }: TabsRootProps) {
  const theme = useTheme();
  const { isHydrated } = useAppState();
  const [active, setActive] = useState<TabRoute>('Dashboard');

  if (!isHydrated) {
    return <View style={[styles.root, { backgroundColor: theme.background }]} />;
  }

  return (
    <View style={[styles.root, { backgroundColor: theme.background }]}>
      <View style={[styles.body, { paddingBottom: TAB_BAR_HEIGHT + 24 }]}>
        {active === 'Dashboard' && <DashboardScreen />}
        {active === 'Transactions' && <TransactionsScreen />}
        {active === 'Budget' && <BudgetScreen />}
        {active === 'Profile' && <ProfileScreen />}
      </View>
      <View style={styles.tabHost}>
        <TabBar
          active={active}
          onSelect={setActive}
          onQuickAdd={() => navigation.navigate('QuickAdd')}
        />
      </View>
      <IncomePromptDialog />
      <UndoSnackbar />
    </View>
  );
}

const styles = StyleSheet.create({
  root: {
    flex: 1
  },
  body: {
    flex: 1
  },
  tabHost: {
    position: 'absolute',
    bottom: 0,
    left: 0,
    right: 0
  }
});
