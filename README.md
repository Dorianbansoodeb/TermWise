# TermWise

Native iOS budgeting and student finance planning app. Tracks income and expenses, separates "money received" from "money assigned to a budget envelope," surfaces recurring bills and variable spending separately, and compares planned vs. actual outcomes month over month.

## Project Status

TermWise is currently a **native iOS app** focused on the following implemented capabilities:

- Tracking income and expenses with quick-add and per-day grouping
- Separating **total income** from **available-to-budget** money (with an explicit user prompt before income is allocated to the envelope)
- Managing recurring bills (paid / upcoming / overdue) and variable spending (pace-based On Track / Watch / Over Budget Risk)
- Comparing **planned budget vs. actual spending** with a "Budget Cushion" and "Unallocated Budget / Over Budget By" summary
- Grouping transactions by date with daily Income / Expenses / Net summaries
- Custom pill-shaped bottom navigation with a floating "Add Transaction" action
- Offline-first persistence (`UserDefaults`-backed cache) with a repository protocol so a remote backend can be swapped in without touching `AppState`
- Domain layer (`Domain/`) and services layer (`Services/`) written in pure Foundation Swift, designed to be ported to Kotlin for a future Android client
- Unit tests for finance/business logic

The following are **planned but not yet implemented**: backend API + cloud sync, authentication (Auth0 / Apple / Google), CSV bank-statement import, receipt scanning, AI-driven insights, and an Android client. See **Roadmap** below.

## Tech Stack

- **Language:** Swift 5 / Swift Concurrency, targeting iOS 17+ (project currently builds against the iOS 26.4 SDK in Xcode 26.4).
- **UI:** SwiftUI (no UIKit, no third-party UI libraries).
- **State:** `ObservableObject` + Combine, with a thin `AppState` coordinator delegating rules to `Domain/` and `Services/`.
- **Persistence:** `UserDefaults`-backed `LocalCacheAppRepository` behind an `AppRepository` protocol; an `OfflineFirstRemoteSyncingAppRepository` extension point is in place for a future API.
- **Charts:** Native SwiftUI `Charts` framework (no third-party chart dependencies).
- **Tests:** XCTest, run via the existing `TermWiseTests` target.

## Project Structure

```
TermWise/
  TermWise/
    Domain/                  pure Foundation rules (cross-platform)
      PlanningTypes.swift    BudgetItem, TransactionItem, BudgetType, etc.
      BudgetSpendCalculator.swift
      FixedBillSchedule.swift
      FixedBillPaidSync.swift
      MarkAsPaidRules.swift
      VariableSpendingPace.swift
      BudgetItemMigration.swift
    Services/                UI-agnostic helpers
      FinanceCalculator.swift   single facade tested by FinanceCalculatorTests
      FinanceBudgetAllocation.swift
      TransactionTotalsService.swift
      BudgetProgressMetrics.swift
      BudgetPlanningService.swift
      SpendingAnalyticsService.swift
      CalendarPeriodKeys.swift
    APIModels.swift          snake_case DTOs for the future backend contract
    AppRepositories.swift    repository protocols + LocalCacheAppRepository
    AppStateDataStore.swift  UserDefaults-backed local cache
    AppState.swift           thin SwiftUI coordinator over Domain/Services
    DashboardView.swift / BudgetPlanView.swift / TransactionsView.swift / ProfilePanelView.swift / MainTabView.swift / AddTransactionView.swift  SwiftUI screens
  TermWiseTests/             XCTest unit tests (FinanceCalculatorTests.swift)
  TermWiseUITests/           UI test target (placeholders only — see Roadmap)
  TermWise.xcodeproj
```

## Known Issues

- Some transaction list rows and status badges (Pinned / Completed / Marked) need better alignment and consistent width across light/dark mode.
- The **Budget Envelope** and **Monthly Snapshot** sections on the Budget screen need clearer wording and a short inline explanation of how each number is derived.
- A few less-visited screens may still need additional bottom spacing so their last visible element is not partially blocked by the custom pill navigation. The shared `MainTabView.bottomNavReservedSpace` constant + `reservesBottomNavSpace()` modifier exist for this — opportunities to apply it more consistently remain.
- The dark-mode login / onboarding flow needs additional manual testing (no automated coverage yet).
- The **Add Budget Item / Recurring Bill** flow currently uses a basic sheet; it can be redesigned as a cleaner modal or bottom-sheet experience with a segmented type picker (Variable / Recurring Bill / Savings Goal).
- No backend exists yet, so all data is local to the device. There is no cross-device sync, no account, and no recovery if the app is uninstalled.

## Roadmap

Planned future work, roughly in priority order:

- Rework the **Add Budget Item** flow into a cleaner modal / bottom sheet with a clearer type picker.
- Add a **legend** to the Plan vs. Reality visualization so the colors and lines are self-explanatory.
- Add a **chart toggle** to switch between Plan vs. Reality and Variable Spending breakdowns.
- Add **Auth0 authentication** with Apple and Google sign-in.
- Add **secure cloud sync** using a backend API (Node/Express or Swift on Server) and MongoDB, behind the existing `RemoteSyncingAppRepository` protocol.
- Add **CSV import** for credit/debit card transaction logs.
- Add **receipt scanning** with itemized expense breakdowns (Vision / VisionKit).
- Add better **transaction filtering** and **category-level analytics** (search, date ranges, per-category trends).
- Add **UI tests** for core user flows after the finance logic is stable.
- Mirror the `Domain/` and `Services/` layers in Kotlin for an **Android client**.

These items are tracked here as commitments to scope, not as features that already work.

## Testing

The project includes XCTest unit tests for the finance/business logic, covering:

- Income vs. available-to-budget calculations (`totalIncome`, `availableToBudget`, `reserveNotBudgeted`, "budgeting more than recorded income" warning)
- Budget difference labels (`Unallocated Budget` / `Over Budget By`, absolute display value, over-budget flag)
- Fixed-bill paid logic (`actual >= planned`, progress fraction, paid / upcoming / overdue status)
- **Mark-as-Paid** behavior (synthetic `mark_as_paid` expense for the remaining amount, bill flips to paid, progress reaches 100%)
- **Undo Mark-as-Paid** behavior (synthetic transaction is removed, actual restored, bill flips back to unpaid)
- Variable spending warnings at 75% / 90% / 100% with anti-repeat tier dedup so the same warning never re-fires within a month
- Fixed vs. variable category separation (Rent / Phone / Tuition-Savings excluded from pace logic; Groceries / Eating Out / Transportation / Fun / Shopping / Other included)
- Variable spending **projection** (`spent / daysElapsed * daysInMonth`) and risk classification (On Track / Watch / Over Budget Risk)
- Transaction filtering summaries for `All`, `Expenses`, and `Income` (with a "Filtered Net" label so partial views don't masquerade as the full picture)
- Daily transaction grouping (newest day first, newest transaction first within each day, accurate per-day Income / Expenses / Net)

Most of this logic lives in `TermWise/Services/FinanceCalculator.swift` (a pure facade over the `Domain/` helpers) so it can be tested without instantiating any SwiftUI view.

### How to run tests

**In Xcode:**
1. Open `TermWise.xcodeproj`.
2. Select the **TermWise** scheme.
3. Press **⌘ + U** (or *Product → Test*).

**From the terminal:**

```bash
xcodebuild \
  -project TermWise.xcodeproj \
  -scheme TermWise \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  test
```

Substitute any installed simulator name (e.g., `iPhone 17 Pro`, `iPhone Air`) for `iPhone 17`.

To run a single test method:

```bash
xcodebuild \
  -project TermWise.xcodeproj \
  -scheme TermWise \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:TermWiseTests/FinanceCalculatorTests/test_markAsPaid_createsRemainingExpense_andMarksBillPaid \
  test
```

UI tests are intentionally not in scope yet — the existing `TermWiseUITests` target only contains the Xcode-generated placeholders. They will be filled in once the finance logic and screens stabilize.

## Getting Started

1. Install **Xcode 26.4** or newer (the project currently targets the iOS 26.4 SDK).
2. Clone the repository and open `TermWise.xcodeproj`.
3. Pick an iOS Simulator (e.g., *iPhone 17*) and press **⌘ + R** to build and run.
4. Press **⌘ + U** at any point to run the unit-test suite.

No package manager bootstrap is required — there are no SPM, CocoaPods, or Carthage dependencies. All code is first-party Swift on top of Apple's frameworks.

## Notes for contributors

- Pure rules belong in `Domain/`. UI-agnostic helpers belong in `Services/`. Anything `@Published` or SwiftUI-specific belongs in `AppState` or a view.
- DTOs in `APIModels.swift` use **snake_case** `CodingKeys` so the same wire format can be consumed by a future backend and Android client.
- When changing a finance rule, prefer adding/updating a test in `FinanceCalculatorTests.swift` first — those tests are the contract the UI relies on.
