/** Cart totals in integer cents. */
export const total = (cents: number[]) => cents.reduce((a, b) => a + b, 0);

/** The number of items in a cart. */
export const count = (cents: number[]) => cents.length;
