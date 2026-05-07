# TermWise domain (cross-platform)

This folder holds **Foundation-only** planning logic: no SwiftUI, Combine, or UIKit.

## Goal

- **iOS** (`TermWise` app target) keeps thin adapters (`AppState`, views) that call into these types.
- **Android** should mirror the same **file names**, **public API**, and **numeric rules** in Kotlin (same package layout under `domain/planning/` is a reasonable convention).
- **Backend** (`backend/` TypeScript) should treat the same strings and fields as canonical where APIs overlap (e.g. `TransactionProvenance.markAsPaid`).

## Files

| Swift | Role |
|-------|------|
| `PlanningTypes.swift` | Codable models + persistence snapshot shape |
| `BudgetSpendCalculator.swift` | Category matching, net expense, fixed vs variable actuals |
| `FixedBillSchedule.swift` | Days-until-due, paid / upcoming / overdue |
| `FixedBillPaidSync.swift` | `isPaid` sync from transactions |
| `MarkAsPaidRules.swift` | `mark_as_paid` provenance + undo eligibility |
| `BudgetItemMigration.swift` | Default / migration rules for loaded budget rows |

## `Services/` (app target, UI-agnostic)

| Swift | Role |
|-------|------|
| `TransactionTotalsService.swift` | Rollups over transactions + budget totals |
| `BudgetProgressMetrics.swift` | Percent-used helpers for charts and lists |
| `BudgetPlanningService.swift` | Urgent bills, onboarding tuition split |
| `SpendingAnalyticsService.swift` | Awareness strings, projections, cumulative spend |
| `CalendarPeriodKeys.swift` | Month/week cache keys |

When you change a rule here, update Android (and any OpenAPI/schema docs) in the same PR whenever possible.

## API wire format

`APIModels.swift` defines **snake_case** `Codable` DTOs that map to these domain types — keep them aligned with `backend/` routes when you formalize the contract.
