import React, { useCallback, useRef, useState } from 'react';
import {
  Dimensions,
  FlatList,
  StyleSheet,
  Text,
  View,
  type ListRenderItem,
  type NativeScrollEvent,
  type NativeSyntheticEvent
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useAppState } from '../state/AppState';
import { useTheme } from '../theme/useTheme';
import { RADIUS, SPACING } from '../theme/tokens';
import { Card } from '../components/Card';
import { PrimaryButton } from '../components/PrimaryButton';

const { width: SCREEN_WIDTH } = Dimensions.get('window');

interface OnboardingStep {
  key: string;
  title: string;
  body: string;
}

const STEPS: OnboardingStep[] = [
  {
    key: 'welcome',
    title: 'Welcome to TermWise',
    body:
      'TermWise helps students track real spending against a monthly plan — so you always know where your money stands.'
  },
  {
    key: 'demo',
    title: 'Sample data included',
    body:
      'We loaded a realistic student budget and transactions so you can explore right away. You can reset to the demo snapshot anytime in Settings.'
  },
  {
    key: 'atb',
    title: 'Available to Budget',
    body:
      'Envelope budgeting starts with money you can assign: income minus savings. Split it across fixed bills, variable spending, and goals — then watch actual spending vs. plan.'
  },
  {
    key: 'start',
    title: "You're all set",
    body:
      'Explore the demo budget, log expenses with Quick Add, and adjust your plan on the Budget tab whenever life changes.'
  }
];

export function OnboardingScreen() {
  const theme = useTheme();
  const { completeOnboarding, resetToDemo } = useAppState();
  const listRef = useRef<FlatList<OnboardingStep>>(null);
  const [pageIndex, setPageIndex] = useState(0);

  const isLastStep = pageIndex === STEPS.length - 1;

  const onScroll = useCallback((e: NativeSyntheticEvent<NativeScrollEvent>) => {
    const index = Math.round(e.nativeEvent.contentOffset.x / SCREEN_WIDTH);
    setPageIndex(index);
  }, []);

  const goNext = useCallback(() => {
    if (isLastStep) return;
    listRef.current?.scrollToIndex({ index: pageIndex + 1, animated: true });
  }, [isLastStep, pageIndex]);

  const onGetStarted = useCallback(() => {
    completeOnboarding();
  }, [completeOnboarding]);

  const onStartFresh = useCallback(async () => {
    await resetToDemo();
    completeOnboarding();
  }, [resetToDemo, completeOnboarding]);

  const renderItem: ListRenderItem<OnboardingStep> = useCallback(
    ({ item }) => (
      <View style={[styles.page, { width: SCREEN_WIDTH }]}>
        <Card style={styles.card}>
          <Text style={[styles.stepTitle, { color: theme.text }]}>{item.title}</Text>
          <Text style={[styles.stepBody, { color: theme.textMuted }]}>{item.body}</Text>
        </Card>
      </View>
    ),
    [theme.text, theme.textMuted]
  );

  return (
    <SafeAreaView style={[styles.root, { backgroundColor: theme.background }]}>
      <View style={styles.header}>
        <Text style={[styles.brand, { color: theme.primary }]}>TermWise</Text>
        <Text style={[styles.tagline, { color: theme.textMuted }]}>Student budget tracker</Text>
      </View>

      <FlatList
        ref={listRef}
        data={STEPS}
        keyExtractor={(item) => item.key}
        renderItem={renderItem}
        horizontal
        pagingEnabled
        showsHorizontalScrollIndicator={false}
        onMomentumScrollEnd={onScroll}
        bounces={false}
        getItemLayout={(_, index) => ({
          length: SCREEN_WIDTH,
          offset: SCREEN_WIDTH * index,
          index
        })}
      />

      <View style={styles.footer}>
        <View style={styles.dots}>
          {STEPS.map((step, i) => (
            <View
              key={step.key}
              style={[
                styles.dot,
                {
                  backgroundColor: i === pageIndex ? theme.primary : theme.border,
                  width: i === pageIndex ? 20 : 8
                }
              ]}
            />
          ))}
        </View>

        {isLastStep ? (
          <View style={styles.actions}>
            <PrimaryButton title="Get started" onPress={onGetStarted} />
            <PrimaryButton
              title="Start fresh"
              variant="secondary"
              onPress={onStartFresh}
              style={styles.secondaryAction}
            />
          </View>
        ) : (
          <PrimaryButton title="Next" onPress={goNext} />
        )}
      </View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  root: {
    flex: 1
  },
  header: {
    paddingHorizontal: SPACING.xl,
    paddingTop: SPACING.lg,
    paddingBottom: SPACING.md,
    alignItems: 'center'
  },
  brand: {
    fontSize: 28,
    fontWeight: '800',
    letterSpacing: -0.5
  },
  tagline: {
    fontSize: 14,
    marginTop: SPACING.xs
  },
  page: {
    paddingHorizontal: SPACING.xl,
    justifyContent: 'center'
  },
  card: {
    minHeight: 200,
    justifyContent: 'center'
  },
  stepTitle: {
    fontSize: 22,
    fontWeight: '700',
    marginBottom: SPACING.md
  },
  stepBody: {
    fontSize: 16,
    lineHeight: 24
  },
  footer: {
    paddingHorizontal: SPACING.xl,
    paddingBottom: SPACING.xl,
    paddingTop: SPACING.md
  },
  dots: {
    flexDirection: 'row',
    justifyContent: 'center',
    alignItems: 'center',
    gap: SPACING.sm,
    marginBottom: SPACING.lg
  },
  dot: {
    height: 8,
    borderRadius: RADIUS.pill
  },
  actions: {
    gap: SPACING.sm
  },
  secondaryAction: {
    marginTop: SPACING.xs
  }
});
