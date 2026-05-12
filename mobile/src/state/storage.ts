import AsyncStorage from '@react-native-async-storage/async-storage';
import type { PersistedState } from '../types/models';

const STORAGE_KEY = '@termwise/persisted-state-v1';

export async function loadPersistedState(): Promise<PersistedState | null> {
  try {
    const raw = await AsyncStorage.getItem(STORAGE_KEY);
    if (!raw) return null;
    const parsed = JSON.parse(raw) as PersistedState;
    if (!parsed || parsed.schemaVersion !== 1) return null;
    return parsed;
  } catch (err) {
    console.warn('[termwise] failed to load persisted state', err);
    return null;
  }
}

export async function savePersistedState(state: PersistedState): Promise<void> {
  try {
    await AsyncStorage.setItem(STORAGE_KEY, JSON.stringify(state));
  } catch (err) {
    console.warn('[termwise] failed to save persisted state', err);
  }
}

export async function clearPersistedState(): Promise<void> {
  try {
    await AsyncStorage.removeItem(STORAGE_KEY);
  } catch {
    /* noop */
  }
}
