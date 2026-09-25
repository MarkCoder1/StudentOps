import { mkdirSync } from "node:fs";
import { dirname } from "node:path";
import Database from "better-sqlite3";

export type StorageDb = InstanceType<typeof Database>;

let defaultDb: StorageDb | null = null;

export function getDefaultDbPath(): string {
  return process.env.OPPORTUNITIES_DB_PATH || "./opportunities.db";
}

export function createDb(path: string = getDefaultDbPath()): StorageDb {
  if (path !== ":memory:") {
    const dir = dirname(path);
    if (dir && dir !== "." && dir !== "/") {
      try {
        mkdirSync(dir, { recursive: true });
      } catch {}
    }
  }
  const db = new Database(path);
  // Enable WAL for better concurrency
  try {
    db.pragma("journal_mode = WAL");
  } catch {}
  initSchema(db);
  return db;
}

export function getSharedDb(): StorageDb {
  if (!defaultDb) {
    defaultDb = createDb();
  }
  return defaultDb;
}

export function closeSharedDb(): void {
  if (defaultDb) {
    try {
      defaultDb.close();
    } catch {}
    defaultDb = null;
  }
}

export function initSchema(db: StorageDb): void {
  db.exec(`
    CREATE TABLE IF NOT EXISTS opportunities (
      id TEXT PRIMARY KEY,
      source TEXT NOT NULL,
      external_id TEXT NOT NULL,
      title TEXT NOT NULL,
      description TEXT,
      organization TEXT,
      official_url TEXT,
      application_url TEXT,
      source_url TEXT,
      category TEXT,
      source_category TEXT,
      subjects TEXT,
      topics TEXT,
      skills TEXT,
      deadline TEXT,
      start_date TEXT,
      end_date TEXT,
      location TEXT,
      cost TEXT,
      benefits TEXT,
      eligibility TEXT,
      provenance TEXT,
      source_metadata TEXT,
      source_records TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      UNIQUE(source, external_id)
    );
    CREATE INDEX IF NOT EXISTS idx_opportunities_source ON opportunities(source);
    CREATE INDEX IF NOT EXISTS idx_opportunities_category ON opportunities(category);
    CREATE INDEX IF NOT EXISTS idx_opportunities_deadline ON opportunities(deadline);
  `);
}

export function createTestDb(): StorageDb {
  return createDb(":memory:");
}
