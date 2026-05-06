import React, { useEffect, useMemo, useState } from 'react';
import { SafeAreaView, ScrollView, StyleSheet, Text, TextInput, TouchableOpacity, View, Dimensions } from 'react-native';
import { StatusBar } from 'expo-status-bar';
import { LineChart } from 'react-native-chart-kit';
import { apiClient } from './src/api/client';
import { DashboardResponse, PlanningPayload, TransactionPayload } from './src/types/api';

const budgetPreset = [
  { name: 'Rent', plannedMonthlyAmount: 900 },
  { name: 'Groceries', plannedMonthlyAmount: 280 },
  { name: 'Transportation', plannedMonthlyAmount: 120 },
  { name: 'Subscriptions', plannedMonthlyAmount: 40 },
  { name: 'Eating Out', plannedMonthlyAmount: 140 }
];

const fullWidth = Dimensions.get('window').width - 32;

export default function App() {
  const [token, setToken] = useState<string | null>(null);
  const [email, setEmail] = useState('student@example.com');
  const [password, setPassword] = useState('password123');
  const [name, setName] = useState('Alex Student');

  const [dashboard, setDashboard] = useState<DashboardResponse | null>(null);
  const [quickAmount, setQuickAmount] = useState('8.75');
  const [quickCategory, setQuickCategory] = useState('Eating Out');
  const [quickDesc, setQuickDesc] = useState('Starbucks');
  const [quickType, setQuickType] = useState<'expense' | 'income'>('expense');

  const authedClient = useMemo(() => apiClient(token ?? undefined), [token]);

  const register = async () => {
    const result = await apiClient().post('/auth/register', { name, email, password });
    setToken(result.token);
  };

  const login = async () => {
    const result = await apiClient().post('/auth/login', { email, password });
    setToken(result.token);
  };

  const setupStarterPlan = async () => {
    const payload: PlanningPayload = {
      incomeSources: [
        {
          name: 'Co-op Job',
          type: 'coop',
          hourlyWage: 22,
          hoursPerWeek: 37.5,
          payFrequency: 'biweekly',
          estimatedTaxRate: 20
        }
      ],
      expenseCategories: budgetPreset,
      tuitionPayments: [{ amount: 4300, dueDate: new Date().toISOString(), description: 'Fall tuition' }],
      fundingSources: [
        { name: 'OSAP', amount: 3000, type: 'loan' },
        { name: 'Scholarship', amount: 800, type: 'scholarship' }
      ],
      savingsGoals: [
        { name: 'Emergency Fund', targetAmount: 2000, currentSavedAmount: 600 },
        { name: 'Next Term Tuition', targetAmount: 4300, currentSavedAmount: 900 }
      ]
    };

    await authedClient.put('/planning', payload);
    await refreshDashboard();
  };

  const addQuickTransaction = async () => {
    const payload: TransactionPayload = {
      type: quickType,
      category: quickCategory,
      description: quickDesc,
      amount: Number(quickAmount)
    };

    await authedClient.post('/transactions', payload);
    await refreshDashboard();
  };

  const refreshDashboard = async () => {
    const data = await authedClient.get<DashboardResponse>('/dashboard');
    setDashboard(data);
  };

  useEffect(() => {
    if (token) {
      refreshDashboard().catch(() => {
        setDashboard(null);
      });
    }
  }, [token]);

  if (!token) {
    return (
      <SafeAreaView style={styles.container}>
        <ScrollView contentContainerStyle={styles.content}>
          <Text style={styles.title}>Student Finance & Co-op Planner</Text>
          <Text style={styles.subtitle}>Plan vs. Reality</Text>

          <TextInput style={styles.input} value={name} onChangeText={setName} placeholder="Name" />
          <TextInput style={styles.input} value={email} onChangeText={setEmail} placeholder="Email" autoCapitalize="none" />
          <TextInput style={styles.input} value={password} onChangeText={setPassword} placeholder="Password" secureTextEntry />

          <TouchableOpacity style={styles.primaryButton} onPress={register}>
            <Text style={styles.buttonText}>Create Account</Text>
          </TouchableOpacity>

          <TouchableOpacity style={styles.secondaryButton} onPress={login}>
            <Text style={styles.secondaryText}>Login</Text>
          </TouchableOpacity>
        </ScrollView>
        <StatusBar style="dark" />
      </SafeAreaView>
    );
  }

  return (
    <SafeAreaView style={styles.container}>
      <ScrollView contentContainerStyle={styles.content}>
        <Text style={styles.title}>Dashboard</Text>
        <Text style={styles.subtitle}>Plan vs. Actual this month</Text>

        <View style={styles.cardRow}>
          <StatCard label="Balance" value={`$${(dashboard?.monthlyBalance ?? 0).toFixed(2)}`} />
          <StatCard label="Spent" value={`$${(dashboard?.monthlyExpenseActual ?? 0).toFixed(2)}`} />
        </View>

        <View style={styles.cardRow}>
          <StatCard label="Planned" value={`$${(dashboard?.plannedMonthlyExpenses ?? 0).toFixed(2)}`} />
          <StatCard label="Delta" value={`$${(dashboard?.planVsActualDelta ?? 0).toFixed(2)}`} />
        </View>

        <TouchableOpacity style={styles.primaryButton} onPress={setupStarterPlan}>
          <Text style={styles.buttonText}>Load Starter Plan</Text>
        </TouchableOpacity>

        <View style={styles.formCard}>
          <Text style={styles.sectionTitle}>Quick Add</Text>
          <View style={styles.toggleRow}>
            <TouchableOpacity
              style={[styles.pill, quickType === 'expense' && styles.activePill]}
              onPress={() => setQuickType('expense')}
            >
              <Text style={[styles.pillText, quickType === 'expense' && styles.activePillText]}>Expense</Text>
            </TouchableOpacity>
            <TouchableOpacity
              style={[styles.pill, quickType === 'income' && styles.activePill]}
              onPress={() => setQuickType('income')}
            >
              <Text style={[styles.pillText, quickType === 'income' && styles.activePillText]}>Income</Text>
            </TouchableOpacity>
          </View>

          <TextInput style={styles.input} value={quickDesc} onChangeText={setQuickDesc} placeholder="Description" />
          <TextInput style={styles.input} value={quickCategory} onChangeText={setQuickCategory} placeholder="Category" />
          <TextInput style={styles.input} value={quickAmount} onChangeText={setQuickAmount} placeholder="Amount" keyboardType="decimal-pad" />

          <TouchableOpacity style={styles.primaryButton} onPress={addQuickTransaction}>
            <Text style={styles.buttonText}>Save Entry</Text>
          </TouchableOpacity>
        </View>

        {!!dashboard && (
          <>
            <Text style={styles.sectionTitle}>Spending Trend</Text>
            <LineChart
              data={{
                labels: ['Plan', 'Actual'],
                datasets: [{ data: [dashboard.plannedMonthlyExpenses, dashboard.monthlyExpenseActual] }]
              }}
              width={fullWidth}
              height={200}
              yAxisLabel="$"
              chartConfig={{
                backgroundGradientFrom: '#ffffff',
                backgroundGradientTo: '#ffffff',
                color: (opacity = 1) => `rgba(37, 99, 235, ${opacity})`,
                labelColor: () => '#334155',
                decimalPlaces: 0
              }}
              bezier
              style={styles.chart}
            />

            <Text style={styles.sectionTitle}>Awareness Messages</Text>
            {(dashboard.messages.length ? dashboard.messages : ['You are on track this month.']).map((message) => (
              <View key={message} style={styles.messageCard}>
                <Text style={styles.messageText}>{message}</Text>
              </View>
            ))}

            <Text style={styles.sectionTitle}>Category Progress</Text>
            {dashboard.categoryProgress.map((item) => (
              <View key={item.category} style={styles.progressRow}>
                <Text style={styles.progressLabel}>{item.category}</Text>
                <Text style={styles.progressValue}>
                  ${item.actual.toFixed(0)} / ${item.planned.toFixed(0)} ({item.percentUsed}%)
                </Text>
              </View>
            ))}
          </>
        )}
      </ScrollView>
      <StatusBar style="dark" />
    </SafeAreaView>
  );
}

type StatCardProps = { label: string; value: string };

function StatCard({ label, value }: StatCardProps) {
  return (
    <View style={styles.statCard}>
      <Text style={styles.statLabel}>{label}</Text>
      <Text style={styles.statValue}>{value}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#f8fafc' },
  content: { padding: 16, paddingBottom: 32 },
  title: { fontSize: 28, fontWeight: '700', color: '#0f172a', marginBottom: 4 },
  subtitle: { color: '#475569', marginBottom: 16 },
  cardRow: { flexDirection: 'row', gap: 12, marginBottom: 12 },
  statCard: { flex: 1, backgroundColor: '#ffffff', padding: 14, borderRadius: 12 },
  statLabel: { color: '#64748b', fontSize: 12 },
  statValue: { color: '#0f172a', fontSize: 20, fontWeight: '700', marginTop: 6 },
  formCard: { backgroundColor: '#ffffff', borderRadius: 12, padding: 12, marginTop: 12 },
  input: {
    backgroundColor: '#ffffff',
    borderWidth: 1,
    borderColor: '#cbd5e1',
    borderRadius: 10,
    paddingHorizontal: 12,
    paddingVertical: 10,
    marginBottom: 10
  },
  primaryButton: { backgroundColor: '#2563eb', paddingVertical: 12, borderRadius: 10, alignItems: 'center', marginBottom: 10 },
  secondaryButton: { borderWidth: 1, borderColor: '#2563eb', paddingVertical: 12, borderRadius: 10, alignItems: 'center', marginBottom: 10 },
  buttonText: { color: '#ffffff', fontWeight: '600' },
  secondaryText: { color: '#2563eb', fontWeight: '600' },
  sectionTitle: { color: '#0f172a', fontWeight: '700', fontSize: 16, marginVertical: 10 },
  chart: { borderRadius: 12, marginBottom: 10 },
  messageCard: { backgroundColor: '#e2e8f0', borderRadius: 10, padding: 10, marginBottom: 8 },
  messageText: { color: '#1e293b' },
  progressRow: { flexDirection: 'row', justifyContent: 'space-between', paddingVertical: 8 },
  progressLabel: { color: '#0f172a', fontWeight: '600' },
  progressValue: { color: '#334155' },
  toggleRow: { flexDirection: 'row', gap: 8, marginBottom: 10 },
  pill: { borderWidth: 1, borderColor: '#94a3b8', borderRadius: 20, paddingHorizontal: 12, paddingVertical: 8 },
  activePill: { backgroundColor: '#2563eb', borderColor: '#2563eb' },
  pillText: { color: '#334155' },
  activePillText: { color: '#ffffff' }
});
