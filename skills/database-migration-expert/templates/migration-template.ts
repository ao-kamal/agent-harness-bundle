import { pgTable, uuid, text, timestamp, uniqueIndex, index } from "drizzle-orm/pg-core";

// Example: new table with indexes + unique constraint.
export const exampleTable = pgTable(
  "example_table",
  {
    id: uuid("id").defaultRandom().primaryKey(),
    externalId: text("external_id").notNull(),
    name: text("name").notNull(),
    createdAt: timestamp("created_at", { withTimezone: true }).defaultNow().notNull(),
  },
  (table) => [
    uniqueIndex("example_table_external_id_unique").on(table.externalId),
    index("example_table_created_at_idx").on(table.createdAt),
  ]
);

// After updating schema.ts:
//   bun run db:generate --name add-example-table
//   bun run db:push
//
// For production indexes, consider a dedicated SQL migration that uses
// CREATE INDEX CONCURRENTLY to avoid blocking writes.
