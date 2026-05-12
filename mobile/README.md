# TermWise Mobile (React Native + Expo)

Cross-platform React Native port of the SwiftUI TermWise prototype. Built with
**Expo + TypeScript** and **React Navigation**, with **AsyncStorage** for local
persistence. The SwiftUI app at `../TermWise` remains the source of truth for
UI, finance rules, and behavior — every screen and rule here is a deliberate
port of the corresponding iOS view/domain helper.

## Run

```bash
cd mobile
npm install
npx expo start
```

Then press `i` for iOS Simulator, `a` for Android Emulator, or scan the QR
with Expo Go on a device.

## What's in here

```
mobile/
├── App.tsx                                 // Provider + navigation root
├── app.json                                // Expo config
├── babel.config.js
├── package.json
├── tsconfig.json
└── src/
    ├── types/
    │   └── models.ts                       // TransactionItem, BudgetItem, ChartRange, ...
    ├── utils/
    │   ├── categories.ts                   // Color palette + variable/fixed classifier
    │   ├── chartCalculator.ts              // Window/series math for spending trend chart
    │   ├── date.ts                         // Pure date helpers (no third-party libs)
    │   ├── financeCalculator.ts            // All finance rules in one testable file
    │   └── format.ts                       // Currency + percent formatting
    ├── state/
    │   ├── AppState.tsx                    // React Context + reducer + persistence
    │   ├── demoData.ts                     // Bundled student demo seed
    │   └── storage.ts                      // AsyncStorage wrapper
    ├── theme/
    │   ├── tokens.ts                       // Light + dark palettes, spacing, radii
    │   └── useTheme.ts
    ├── navigation/
    │   ├── RootNavigator.tsx               // Stack: Tabs + modal Quick Add
    │   ├── TabBar.tsx                      // Custom pill nav + orange FAB
    │   └── constants.ts
    ├── screens/
    │   ├── DashboardScreen.tsx             // Spend trend, plan vs reality, recent txns
    │   ├── TransactionsScreen.tsx          // Grouped by date with filter pills
    │   ├── BudgetScreen.tsx                // Envelope, Savings Target, bills, variable
    │   ├── ProfileScreen.tsx               // Monthly note, savings rate, reset
    │   └── QuickAddScreen.tsx              // Modal Add Expense/Income
    └── components/
        ├── BillRow.tsx                     // Fixed bill row + Mark as Paid
        ├── BudgetEnvelopeCard.tsx
        ├── Card.tsx
        ├── IncomePromptDialog.tsx          // "Add this income to your budget?"
        ├── PillBadge.tsx
        ├── PlanVsRealityBar.tsx            // Segmented bar + expandable legend
        ├── PrimaryButton.tsx
        ├── SavingsTargetCard.tsx
        ├── SpendTrendChart.tsx             // SVG chart with tooltip + projection
        ├── SpendTrendRangePicker.tsx       // 7D / 1W / 30D / Month pill picker
        ├── TransactionGroupList.tsx
        └── UndoSnackbar.tsx                // 5s auto-dismiss above bottom nav
```

## Finance rules preserved from SwiftUI

- `totalIncome`, `availableToBudget`, `reserveNotBudgeted`, `totalBudgeted`
  (fixed + variable planned only — **not** savings target dollars),
  `budgetDifference`, `unallocatedRow`
  (`Unallocated Budget` / `Over Budget By` using
  `available − totalBudgeted`). Savings Target is a separate comfort goal and
  never folds into the envelope difference.
- `savingsTarget` = explicit override OR `desiredSavingsRate × availableToBudget`.
- `usableBudgetAfterSavings` = `max(0, available − savings)`.
- Variable Spending Pace: risk band ≤90% / ≤100% / >100% of variable limit.
- Total Spending Pace: anchors at today's actual; future is only the variable
  daily rate extrapolated + `unpaidFixedBillsRemaining`. Paying a fixed bill
  cannot make the month-end projection worse.
- Recurring bill statuses: `unpaid` / `partial` / `paid` based on
  `actualPaid` vs `planned`.
- Mark as Paid creates a transaction for the remaining amount, then schedules
  a 5s Undo snackbar that restores the prior actual.
- Quick Add income prompts "Add this income to your budget?" with `Add to
  Budget`, `Keep as Reserve`, `Cancel`.

## Migrated features

| Area | Status |
| --- | --- |
| Custom bottom pill navigation + orange FAB | ✅ |
| Dashboard with income header, spend trend, Plan vs Reality, recent txns | ✅ |
| Transactions screen with All / Expenses / Income filters, grouped by day | ✅ |
| Budget screen: envelope, Savings Target, bills, variable, savings goals | ✅ |
| Profile: monthly note, override Available to Budget, savings rate/target, reset | ✅ |
| Quick Add modal with expense/income toggle and preset categories | ✅ |
| Variable Spending Trend chart with 7D / 1W / 30D / Month | ✅ |
| Total Spending Trend chart (Month-only) | ✅ |
| Tooltip contract matches iOS (Spend Limit only on the line, never in tooltip) | ✅ |
| Light + Dark mode (driven by system) | ✅ |
| AsyncStorage persistence (transactions, budgets, settings, note, chart mode/range) | ✅ |
| Demo data (income, rent, phone, tuition savings, groceries, eating out, ...) | ✅ |
| Income prompt dialog after adding income | ✅ |
| Mark-as-Paid + 5s auto-dismiss Undo snackbar | ✅ |
| Pure TypeScript finance/chart helpers (testable, framework-free) | ✅ |

## Future work (not in this pass)

- Auth0 sign-in / sign-up flow.
- Node + Express + MongoDB Atlas + Mongoose backend sync (replace AsyncStorage
  with a repository layer that mirrors the SwiftUI `PersistedState`).
- Bank linking, receipt scanning, widgets.
- Editing recurring bills + variable categories inside the app (current UI
  shows the demo budget; CRUD is still local-only).
- Unit + UI test harness (`jest-expo` + `@testing-library/react-native`).
- Polishing icons (current tab icons use Unicode glyphs; a vector icon font
  pass is next).
