/** Cart totals in integer cents. */
export const total = (cents: number[]) => cents.reduce((a, b) => a + b, 0);
