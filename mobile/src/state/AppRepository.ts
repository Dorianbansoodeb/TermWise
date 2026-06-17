import type { PersistedState } from '../types/models';
import {
  clearPersistedState,
  loadPersistedState,
  savePersistedState
} from './storage';

export interface AppRepository {
  load(): Promise<PersistedState | null>;
  save(state: PersistedState): Promise<void>;
  clear(): Promise<void>;
}

export class LocalAppRepository implements AppRepository {
  load(): Promise<PersistedState | null> {
    return loadPersistedState();
  }

  save(state: PersistedState): Promise<void> {
    return savePersistedState(state);
  }

  clear(): Promise<void> {
    return clearPersistedState();
  }
}

export const defaultAppRepository: AppRepository = new LocalAppRepository();
