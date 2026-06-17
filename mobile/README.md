# TermWise Mobile (React Native + Expo)

Cross-platform React Native port of the SwiftUI TermWise prototype. Built with
**Expo + TypeScript** and **React Navigation**, with **AsyncStorage** for local
persistence. The SwiftUI app at `../TermWise` remains the source of truth for
finance rules — domain helpers in `src/utils/` mirror the iOS calculators.

## Run

```bash
cd mobile
npm install
npx expo start --localhost
```

Then press `i` for iOS Simulator. Prefer `--localhost` over LAN URLs in the
simulator (more reliable than `192.168.x.x`).

```bash
npx expo start --localhost --ios   # one step
```

**Verify:** `npm run typecheck` · `npm test` (91 tests)

## Current app (main)

| Area | What ships today |
| --- | --- |
| **Onboarding** | 4-step first-run intro (demo data, Available to Budget) |
| **Home** | Available to Budget hero, spend trend (variable ↔ total), plan vs reality, recent txns + See all |
| **Quick Add** | Simple default (category + amount + date chips); Advanced for recurring/variable routing |
| **Transactions** | All / Expenses / Income + category pills; tap to **edit**, swipe to delete + 5s undo |
| **Budget** | Envelope, savings target, snapshot, add budget item, month breakdown pie (tap ✎ to edit), bills, variable categories |
| **Bills** | Mark paid, edit, delete; badges **Paid / Partial / Upcoming / Overdue** |
| **Profile** | Past months chart, monthly note, estimated breakdown disclaimer |
| **Settings** | Theme, currency, budget warning threshold (wired to pace), JSON **export**; reminders marked Coming soon |
| **Persistence** | `AppRepository` → AsyncStorage, schema migration v1, month rollover, deduped demo seed |

## Architecture

```
src/state/
  AppState.tsx          Context + mutations
  AppRepository.ts      load / save / clear (local today; remote later)
  storage.ts            AsyncStorage + migratePersistedState + month prep
src/utils/
  financeCalculator.ts  Budget math (parity with Swift)
  chartCalculator.ts    Spend trend series
```

## Finance rules (Swift parity)

- Envelope: `availableToBudget`, `totalBudgeted` (fixed + variable only — savings
  target excluded from envelope math), `unallocatedRow`.
- Variable pace: configurable warning threshold (Settings, default 90%).
- Total pace: projection includes unpaid fixed bills for the month.
- Bill status: `paid` / `partial` / `upcoming` / `overdue` from due day vs today.

## What's next (before Google Sign-In + MongoDB)

These are the remaining gaps worth closing **on local-only** before cloud auth:

1. **Push notifications** — wire bill-due / budget-warning toggles (currently Coming soon in Settings).
2. **Accessibility** — chart text summary, VoiceOver alternative to swipe-delete.
3. **Transaction search** — filter by text across long lists.
4. **Savings goals UI** — `budgetType: 'savings'` exists in models; no dedicated screen yet.
5. **Import JSON** — export exists; import/restore from Settings backup file.
6. **Component / E2E tests** — logic covered by Vitest; no `jest-expo` UI harness yet.

## After local polish → backend phase

| Step | Work |
| --- | --- |
| 1 | **Google Sign-In** — auth screen, secure token storage, account linking |
| 2 | **MongoDB + API** — `RemoteAppRepository`, user-scoped `PersistedState`, offline queue + conflict rules |
| 3 | **Sync** — replace one-device AsyncStorage as source of truth for signed-in users |
| 4 | Optional | Bank linking, receipts, widgets |

`AppRepository` is intentionally in place so step 2 swaps the implementation
without rewriting screens.

## Grade snapshot (student POV)

| | |
| --- | --- |
| **Overall** | **B+** — strong planning/analytics; solid daily use; local-only |
| Planning & insights | A |
| Daily logging & edits | B+ |
| Onboarding & clarity | B |
| Pre-backend engineering | A- |
