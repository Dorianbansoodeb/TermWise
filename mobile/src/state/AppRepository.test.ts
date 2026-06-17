import { describe, expect, it } from 'vitest';
import type { PersistedState } from '../types/models';
import { DEFAULT_APP_USER_SETTINGS } from '../types/models';
import type { AppRepository } from './AppRepository';
import { LocalAppRepository } from './AppRepository';
import { buildDemoState } from './demoData';

class InMemoryAppRepository implements AppRepository {
  private state: PersistedState | null = null;

  load(): Promise<PersistedState | null> {
    return Promise.resolve(this.state);
  }

  save(state: PersistedState): Promise<void> {
    this.state = state;
    return Promise.resolve();
  }

  clear(): Promise<void> {
    this.state = null;
    return Promise.resolve();
  }
}

function minimalState(): PersistedState {
  return {
    schemaVersion: 1,
    transactions: [],
    budgetItems: [],
    monthlySettingsByMonth: {},
    monthlyNotes: {},
    chartMode: 'variable',
    variableChartRange: 'currentMonth',
    appUserSettings: DEFAULT_APP_USER_SETTINGS
  };
}

describe('InMemoryAppRepository', () => {
  it('returns null before any save', async () => {
    const repo = new InMemoryAppRepository();
    await expect(repo.load()).resolves.toBeNull();
  });

  it('round-trips persisted state through save and load', async () => {
    const repo = new InMemoryAppRepository();
    const state = buildDemoState(new Date('2026-06-15T12:00:00Z'));

    await repo.save(state);
    await expect(repo.load()).resolves.toEqual(state);
  });

  it('clears stored state', async () => {
    const repo = new InMemoryAppRepository();
    await repo.save(minimalState());
    await repo.clear();
    await expect(repo.load()).resolves.toBeNull();
  });
});

describe('LocalAppRepository', () => {
  it('implements the AppRepository interface', () => {
    const repo: AppRepository = new LocalAppRepository();
    expect(typeof repo.load).toBe('function');
    expect(typeof repo.save).toBe('function');
    expect(typeof repo.clear).toBe('function');
  });
});
