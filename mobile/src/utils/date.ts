// Pure date helpers used by the finance + chart calculators. Keeping them in
// one file so unit tests do not need to stub Date or pull in a third-party
// library (parity with iOS's `Calendar.current` usage in domain code).

const TWO = (n: number): string => (n < 10 ? `0${n}` : `${n}`);

const MONTH_LABELS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

export function monthKey(date: Date): string {
  return `${date.getFullYear()}-${TWO(date.getMonth() + 1)}`;
}

export function isSameMonth(a: Date, b: Date): boolean {
  return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth();
}

export function isSameDay(a: Date, b: Date): boolean {
  return (
    a.getFullYear() === b.getFullYear() &&
    a.getMonth() === b.getMonth() &&
    a.getDate() === b.getDate()
  );
}

export function startOfDay(date: Date): Date {
  const next = new Date(date);
  next.setHours(0, 0, 0, 0);
  return next;
}

export function daysInMonth(date: Date): number {
  return new Date(date.getFullYear(), date.getMonth() + 1, 0).getDate();
}

export function addDays(date: Date, days: number): Date {
  const next = new Date(date);
  next.setDate(next.getDate() + days);
  return next;
}

export function startOfMonth(date: Date): Date {
  return new Date(date.getFullYear(), date.getMonth(), 1, 0, 0, 0, 0);
}

export function addMonths(date: Date, delta: number): Date {
  const next = new Date(date);
  next.setMonth(next.getMonth() + delta);
  return next;
}

/// `monthKey` → first day of that month (for labels / modals).
export function parseMonthKey(key: string): Date {
  const parts = key.split('-');
  const y = Number(parts[0]);
  const m = Number(parts[1]);
  if (!Number.isFinite(y) || !Number.isFinite(m)) {
    return new Date();
  }
  return new Date(y, m - 1, 1, 0, 0, 0, 0);
}

export function shortMonthLabel(date: Date): string {
  return MONTH_LABELS[date.getMonth()] ?? '';
}

export function monthYearLabel(date: Date): string {
  return `${MONTH_LABELS[date.getMonth()]} ${date.getFullYear()}`;
}

export function dayKey(date: Date): string {
  return `${date.getFullYear()}-${TWO(date.getMonth() + 1)}-${TWO(date.getDate())}`;
}

export function parseDate(value: string | Date): Date {
  return value instanceof Date ? value : new Date(value);
}

/// Calendar day for persisted ISO strings — avoids UTC midnight shifting the local date.
export function parseCalendarDate(value: string | Date): Date {
  if (value instanceof Date) return startOfDay(value);
  const isoDay = /^(\d{4})-(\d{2})-(\d{2})/.exec(value);
  if (isoDay) {
    return new Date(
      Number(isoDay[1]),
      Number(isoDay[2]) - 1,
      Number(isoDay[3]),
      12,
      0,
      0,
      0
    );
  }
  return startOfDay(new Date(value));
}

/// Stable local calendar timestamp for demo seeds and new transactions.
export function calendarDateISO(date: Date): string {
  const d = startOfDay(date);
  return `${dayKey(d)}T12:00:00.000`;
}

/// "Today", "Yesterday", or "Mon, May 12" — same vibe as iOS dashboard grouping.
export function relativeDayLabel(date: Date, now: Date = new Date()): string {
  if (isSameDay(date, now)) return 'Today';
  const yesterday = addDays(now, -1);
  if (isSameDay(date, yesterday)) return 'Yesterday';
  const weekdays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  const monthLabel = MONTH_LABELS[date.getMonth()];
  return `${weekdays[date.getDay()]}, ${monthLabel} ${date.getDate()}`;
}

export function shortMonthDay(date: Date): string {
  const monthLabel = MONTH_LABELS[date.getMonth()];
  return `${monthLabel} ${date.getDate()}`;
}
