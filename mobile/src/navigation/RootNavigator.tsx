import React, { useState } from 'react';
import { ActivityIndicator, StyleSheet, View } from 'react-native';
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
import { SettingsScreen } from '../screens/SettingsScreen';
import { OnboardingScreen } from '../screens/OnboardingScreen';
import { IncomePromptDialog } from '../components/IncomePromptDialog';
import { UndoSnackbar } from '../components/UndoSnackbar';
import { TabBar } from './TabBar';
import type { RootStackParamList, TabRoute } from './constants';

const RootStack = createNativeStackNavigator<RootStackParamList>();

export function RootNavigator() {
  const theme = useTheme();
  const { isHydrated, hasCompletedOnboarding } = useAppState();
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

  if (!isHydrated) {
    return (
      <View style={[styles.loading, { backgroundColor: theme.background }]}>
        <ActivityIndicator size="large" color={theme.primary} />
      </View>
    );
  }

  if (!hasCompletedOnboarding) {
    return <OnboardingScreen />;
  }

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
        <RootStack.Screen
          name="Settings"
          component={SettingsScreen}
          options={{
            headerShown: true,
            title: 'Settings',
            headerStyle: { backgroundColor: theme.background },
            headerTintColor: theme.primary,
            headerTitleStyle: { color: theme.text, fontWeight: '700' },
            headerShadowVisible: false,
            contentStyle: { backgroundColor: theme.background }
          }}
        />
      </RootStack.Navigator>
    </NavigationContainer>
  );
}

type TabsRootProps = NativeStackScreenProps<RootStackParamList, 'Tabs'>;

function TabsRoot({ navigation }: TabsRootProps) {
  const theme = useTheme();
  const [active, setActive] = useState<TabRoute>('Dashboard');

  return (
    <View style={[styles.root, { backgroundColor: theme.background }]}>
      <View style={styles.body}>
        {active === 'Dashboard' && (
          <DashboardScreen onNavigateToTransactions={() => setActive('Transactions')} />
        )}
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
  loading: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center'
  },
  root: {
    flex: 1
  },
  body: {
    flex: 1
  },
  tabHost: {
    ...StyleSheet.absoluteFillObject,
    pointerEvents: 'box-none'
  }
});
