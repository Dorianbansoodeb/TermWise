export const startOfMonth = (date: Date): Date => new Date(date.getFullYear(), date.getMonth(), 1, 0, 0, 0, 0);

export const endOfMonth = (date: Date): Date => new Date(date.getFullYear(), date.getMonth() + 1, 0, 23, 59, 59, 999);
