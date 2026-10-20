import { sql } from "../db";
import { lockCart } from "./lock";

export async function finaliseCart(id: string) {
  await sql`begin`;
  try {
    await lockCart(id);
    await sql`update carts set finalised_at = now() where id = ${id} and finalised_at is null`;
    await sql`commit`;
  } catch (error) {
    await sql`rollback`;
    throw error;
  }
}
