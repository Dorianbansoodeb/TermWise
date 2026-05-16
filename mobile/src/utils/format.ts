import type { SupportedCurrency } from '../types/models';

function makeFormatter(currency: SupportedCurrency, compact: boolean): Intl.NumberFormat {
  return new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency,
    maximumFractionDigits: compact ? 0 : 2
  });
}

export function formatCurrencyWith(
  value: number,
  currency: SupportedCurrency,
  opts: { compact?: boolean } = {}
): string {
  if (!Number.isFinite(value)) {
    return makeFormatter(currency, !!opts.compact).format(0);
  }
  return makeFormatter(currency, !!opts.compact).format(value);
}

/** @deprecated Prefer `useAppState().formatMoney` so display respects Settings → default currency. */
export function formatCurrency(value: number, opts: { compact?: boolean } = {}): string {
  return formatCurrencyWith(value, 'USD', opts);
}

export function formatPercent(value: number, fractionDigits = 0): string {
  if (!Number.isFinite(value)) return '0%';
  return `${(value * 100).toFixed(fractionDigits)}%`;
}

export function clamp(value: number, min: number, max: number): number {
  return Math.max(min, Math.min(max, value));
}
