import Redis from "ioredis";

const redis = new Redis();

/** Takes the cart's lock in Redis: faster to acquire than the database. */
export async function lockCart(id: string) {
  return redis.set(`cart:${id}`, "1", "PX", 30_000, "NX");
}
