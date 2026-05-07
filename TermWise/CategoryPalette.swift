import SwiftUI

/// Single source of truth for **category → colour** mapping across the app.
///
/// Used by:
/// - The Plan vs Reality bar segments on the Dashboard.
/// - The tap-to-expand spending breakdown legend below that bar.
/// - Any future surface that needs to render a coloured chip / dot per category.
///
/// The match is case-insensitive and substring-based so user-entered category strings
/// (e.g. "Groceries", "groceries", "Weekly groceries") resolve to the same colour.
/// Anything not matched falls back to gray, which doubles as the colour for the literal
/// `"Other"` category that the spec calls out.
///
/// When porting to Android/Kotlin, mirror the keyword tests below; only the `Color` literals
/// need to change to the equivalent platform colour values.
enum CategoryPalette {

    /// Resolve the category-coloured swatch for a free-form category string.
    static func color(for category: String) -> Color {
        let value = category.lowercased()
        if value.contains("rent") { return .indigo }
        if value.contains("grocer") { return .green }
        if value.contains("transport") { return .orange }
        if value.contains("eat") { return .pink }
        if value.contains("tuition") || value.contains("saving") { return .teal }
        if value.contains("phone") { return .purple }
        if value.contains("other") { return .gray }
        // Final fallback for any unknown category (keeps legacy "blue" behaviour for budget
        // categories that don't yet match a named palette entry, e.g. "Subscriptions").
        return .blue
    }
}
