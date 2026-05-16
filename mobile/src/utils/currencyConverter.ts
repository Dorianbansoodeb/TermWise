import type { SupportedCurrency } from '../types/models';

// TODO: Replace with live exchange-rate API (no paid calls in this branch).

/** Approximate static rates: value = how many USD one unit of `code` is worth. */
const USD_PER_UNIT: Record<SupportedCurrency, number> = {
  USD: 1,
  CAD: 0.71,
  EUR: 1.08,
  GBP: 1.27
};

export function convertCurrency(
  amount: number,
  from: SupportedCurrency,
  to: SupportedCurrency
): number {
  if (!Number.isFinite(amount)) return 0;
  if (from === to) return amount;
  const usd = amount * USD_PER_UNIT[from];
  return usd / USD_PER_UNIT[to];
}
