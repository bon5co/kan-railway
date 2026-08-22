import { type Config } from "drizzle-kit";

// Same as upstream packages/db/drizzle.config.ts, except `ssl` is off: on
// Railway the app talks to Postgres over the project-private network, which
// never leaves Railway's backbone, and the stock `postgres` image serves no
// TLS certificate at all.
export default {
  schema: "./src/schema",
  out: "./migrations",
  dialect: "postgresql",
  dbCredentials: {
    url: process.env.POSTGRES_URL ?? "",
    ssl: process.env.POSTGRES_SSL === "true",
  },
  migrations: {
    prefix: "timestamp",
  },
} satisfies Config;
