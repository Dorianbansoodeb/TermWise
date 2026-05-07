import Foundation

/// Wire format + rules shared with backend / Android for synthetic bill-close transactions.
enum TransactionProvenance {
    static let markAsPaid = "mark_as_paid"
}

enum MarkAsPaidRules {

    /// Remaining currency amount to add so that actual can reach `planned`, or nil if already satisfied.
    static func remainingAmountToReachPlanned(planned: Double, actualPaid: Double) -> Double? {
        guard actualPaid < planned else { return nil }
        let remaining = planned - actualPaid
        return remaining > 0 ? remaining : nil
    }

    static func qualifiesForUndo(transaction: TransactionItem, billId: UUID) -> Bool {
        transaction.billId == billId
            && transaction.source == TransactionProvenance.markAsPaid
            && transaction.undoable
    }
}
