import pg from "pg";

const pool = new pg.Pool();

export async function sql(strings: TemplateStringsArray, ...values: unknown[]) {
  const text = strings.reduce((acc, s, i) => `${acc}$${i}${s}`);
  return pool.query(text, values);
}
