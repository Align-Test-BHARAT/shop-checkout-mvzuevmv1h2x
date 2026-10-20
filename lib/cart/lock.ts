import { sql } from "../db";

const RETRIES = 3;
const TIMEOUT_MS = 5_000;

const jitter = (attempt: number) => 100 * 2 ** attempt + Math.floor(Math.random() * 100);

/** Takes the cart's advisory lock inside the current transaction: retried three times with jitter, five seconds each. */
export async function lockCart(id: string) {
  for (let attempt = 0; ; attempt++) {
    try {
      await sql`set local lock_timeout = ${TIMEOUT_MS}`;
      return await sql`select pg_advisory_xact_lock(hashtext(${id}))`;
    } catch (error) {
      if (attempt >= RETRIES - 1) throw error;
      await new Promise((r) => setTimeout(r, jitter(attempt)));
    }
  }
}
