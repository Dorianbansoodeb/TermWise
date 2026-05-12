// Pure date helpers used by the finance + chart calculators. Keeping them in
// one file so unit tests do not need to stub Date or pull in a third-party
// library (parity with iOS's `Calendar.current` usage in domain code).

const TWO = (n: number): string => (n < 10 ? `0${n}` : `${n}`);

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

export function dayKey(date: Date): string {
  return `${date.getFullYear()}-${TWO(date.getMonth() + 1)}-${TWO(date.getDate())}`;
}

export function parseDate(value: string | Date): Date {
  return value instanceof Date ? value : new Date(value);
}

const MONTH_LABELS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

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
