import { describe, expect, it } from 'vitest';
import { buildDemoState } from './demoData';
import { migratePersistedState, prepareStateForReferenceMonth } from './storage';

describe('migratePersistedState', () => {
  it('migrates schema version 1 snapshots', () => {
    const demo = buildDemoState(new Date(2026, 5, 17, 12, 0, 0));
    const migrated = migratePersistedState(demo);

    expect(migrated).not.toBeNull();
    expect(migrated?.schemaVersion).toBe(1);
    expect(migrated?.transactions.length).toBe(demo.transactions.length);
    expect(migrated?.lastDemoSeedMonthKey).toBe('2026-06');
  });

  it('returns null for invalid or unsupported schema versions', () => {
    expect(migratePersistedState(null)).toBeNull();
    expect(migratePersistedState(undefined)).toBeNull();
    expect(migratePersistedState({})).toBeNull();
    expect(migratePersistedState({ schemaVersion: 0 })).toBeNull();
    expect(migratePersistedState({ schemaVersion: 99 })).toBeNull();
  });

  it('normalizes legacy variableChartRange values', () => {
    const demo = buildDemoState();
    const migrated = migratePersistedState({
      ...demo,
      variableChartRange: 'oneWeek'
    });

    expect(migrated?.variableChartRange).toBe('sevenDays');
  });

  it('preserves lastDemoSeedMonthKey when present and omits it when missing', () => {
    const demo = buildDemoState();
    const withKey = migratePersistedState({ ...demo, lastDemoSeedMonthKey: '2026-03' });
    expect(withKey?.lastDemoSeedMonthKey).toBe('2026-03');

    const { lastDemoSeedMonthKey: _ignored, ...withoutKey } = demo;
    const migrated = migratePersistedState(withoutKey);
    expect(migrated?.lastDemoSeedMonthKey).toBeUndefined();
  });
});

describe('prepareStateForReferenceMonth', () => {
  it('seeds demo transactions when persisted data is from a prior month', () => {
    const march = new Date(2026, 2, 17, 12, 0, 0);
    const june = new Date(2026, 5, 17, 12, 0, 0);
    const stale = buildDemoState(march);
    const { lastDemoSeedMonthKey: _ignored, ...legacyStale } = stale;

    const hydrated = prepareStateForReferenceMonth(legacyStale, june);
    const hasJuneExpense = hydrated.transactions.some(
      (t) => t.type === 'expense' && t.date.startsWith('2026-06')
    );

    expect(hydrated.transactions.length).toBeGreaterThan(stale.transactions.length);
    expect(hasJuneExpense).toBe(true);
    expect(hydrated.monthlySettingsByMonth['2026-06']).toBeDefined();
    expect(hydrated.lastDemoSeedMonthKey).toBe('2026-06');
  });

  it('does not re-seed demo transactions when already seeded this month', () => {
    const march = new Date(2026, 2, 17, 12, 0, 0);
    const june = new Date(2026, 5, 17, 12, 0, 0);
    const stale = buildDemoState(march);
    const { lastDemoSeedMonthKey: _ignored, ...legacyStale } = stale;

    const hydrated = prepareStateForReferenceMonth(legacyStale, june);
    const again = prepareStateForReferenceMonth(hydrated, june);

    expect(again.transactions.length).toBe(hydrated.transactions.length);
    expect(again.lastDemoSeedMonthKey).toBe('2026-06');
  });

  it('does not seed when the reference month already has expenses', () => {
    const june = new Date(2026, 5, 17, 12, 0, 0);
    const seeded = buildDemoState(june);

    const hydrated = prepareStateForReferenceMonth(seeded, june);

    expect(hydrated.transactions.length).toBe(seeded.transactions.length);
    expect(hydrated.lastDemoSeedMonthKey).toBe('2026-06');
  });
});
