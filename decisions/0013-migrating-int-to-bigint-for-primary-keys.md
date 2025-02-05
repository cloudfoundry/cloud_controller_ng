# 13: Migrating `int` to `bigint` for `id` Primary Keys

Date: 2025-02-04

## Status

Draft :construction:

## Context

The primary key `id` columns in all database tables use the integer type, which has a maximum value of 2,147,483,647.
As foundations grow over time, the `id` values in some of these tables (e.g., events) are approaching this limit.
If the limit is reached, the cloud controller will be unable to insert new records, leading to critical failures in the CF API.  
E.g.:
```
PG::SequenceGeneratorLimitExceeded: ERROR:  nextval: reached maximum value of sequence "events_id_seq"
```
The goal is to migrate these primary key `id` columns from `int` to `bigint` without causing downtime and to ensure compatibility across PostgreSQL and MySQL databases.
This migration must:
- Avoid downtime since the CF API is actively used in production.
- Handle tables with millions of records efficiently. 
- Provide a safe rollback mechanism in case of issues during the migration.
- Be reusable for other tables in the future.
- Ensure that migration only is executed when id_bigint is fully populated.

The largest tables in a long-running foundation are `events`, `delayed_jobs`, `jobs`, and `app_usage_events`.

## Decisions

### Scope

The `events` table will be migrated first as it has the most significant growth in `id` values.
Other tables will be migrated at a later stage.

### Phased Migration
The migration will be conducted in multiple steps to ensure minimal risk.
#### Step 1 - Preparation
- Add a new column `id_bigint` of type `bigint` to the target table. If the `id` column is referenced as a foreign key in other tables, also add an `<ref>_id_bigint` column in those referencing tables.
- Create triggers to keep `id_bigint` in sync with `id` when new records are inserted.
- Add constraints and indexes to `id_bigint` as required to match primary key and foreign key requirements.

#### Step 2 - Backfill
- Use a batch-processing script (e.g. a delayed job) to populate `id_bigint` for existing rows in both the primary table and, if applicable, all foreign key references.
- Table locks will be avoided by using a batch processing approach.
- In case the table has configurable cleanup duration, the backfill job will only process records which are beyond the cleanup duration to reduce the number of records to be processed. 
- Backfill will be executed outside the migration due to its potentially long runtime.
- If necessary the backfill will run over multiple releases.

#### Step 3a - Migration Pre Check
- Double check that `id_bigint` is fully populated before proceeding.
- In case the backfill is not yet complete or the `id_bigint` column is not fully populated the migration exits gracefully and is retried in the next deploy.
#### Step 3b - Actual Migration
- Retain the `id` column as a backup by renaming it to `id_old`.
- If foreign keys exist, rename the corresponding id columns in referencing tables to `<ref>_id_old` as well.
- Remove the sync triggers.
- Switch the primary key by renaming `id_bigint` to `id`.
- If foreign keys exist, rename `id_bigint` to `id` in referencing tables accordingly.
- Create new sync triggers for keeping `id` and `id_bigint` in sync for newly inserted records.
- Everything is done in a single transaction to ensure consistency.
#### Step 4 - Cleanup
- Remove remaining sync triggers.
- Drop the `id_old` column after verifying stability and ensuring the system fully relies on the migrated id column
- If foreign keys exist, drop the `id_old` columns in referencing tables after verification.

### Rollback Mechanism
Retain the original `id` column until the cleanup phase, allowing for reversion to the previous state if needed.

### Standardized Approach
Write reusable scripts for adding `id_bigin`t, setting up triggers, backfilling data, and verifying migration readiness.

### Release Strategy

Steps 1-2 will be released as a cf-deployment major release to ensure that the database is prepared for the migration.  
Steps 3-4 will be released as a subsequent cf-deployment major release to complete the migration.  
Between these releases there should be a reasonable time to allow the backfill to complete.

For the `events` table there is a default cleanup interval of 31 days. Therefore for the `events` table the gap between the releases should be around 60 days.

## Consequences
### Positive Consequences

- Future-proofing the schema for tables with high record counts.
- Minimal downtime due to the phased approach.
- A standardized process for similar migrations across the database.

### Negative Consequences

- Increased complexity in the migration process.
- Potentially long runtimes for backfilling data in tables with millions of records.
- Requires careful coordination across multiple CAPI/CF-Deployment versions.
- If backfilling encounters edge cases (e.g., missing cleanup jobs), the migration may be delayed until operators intervene.

## Rollback Plan
Keep the original id column intact until the final cleanup phase.
If issues arise during the switch, revert the primary key to id.

## Alternatives Considered

### Switching to `guid` Field as Primary Key

Pros: Provides globally unique identifiers and eliminates the risk of overflow.

Cons: Might decrease query and index performance, requires significant changes for foreign key constraints, and introduces non-sequential keys.

Reason Rejected: The overhead and complexity outweighed the benefits for our use case.

### Implementing Rollover for `id` Reuse

Pros: Delays the overflow issue by reusing IDs from deleted rows. Minimal schema changes.

Cons: Potential issues with foreign key constraints and increased complexity in the rollover process. Could be problematic for tables which do not have frequent deletions.

Reason Rejected: Might work well for tables like events, but not a universal solution for all tables where there is no guarantee of frequent deletions.


### Direct Migration of `id` to `bigint` via `ALTER TABLE` Statement

Pros: One-step migration process.

Cons: Requires downtime, locks the table for the duration of the migration, and can be slow for tables with millions of records.

Reason Rejected: Downtimes are unacceptable for productive foundations.


## Example Migration Scripts With PostgreSQL Syntax

### Step 1 - Preparation
```sql
BEGIN;

-- Add new BIGINT column
ALTER TABLE events ADD COLUMN id_bigint BIGINT;

-- Ensure new inserts populate `id_bigint`
CREATE OR REPLACE FUNCTION events_set_id_bigint_on_insert()
RETURNS TRIGGER AS $$
BEGIN
    NEW.id_bigint := NEW.id;
RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_events_set_id_bigint ON events;

CREATE TRIGGER trigger_events_set_id_bigint
    BEFORE INSERT ON events
    FOR EACH ROW
    EXECUTE FUNCTION events_set_id_bigint_on_insert();

COMMIT;

```

### Step 2 - Backfill
```sql
WITH batch AS (
    SELECT id FROM events
    WHERE id_bigint IS NULL
    ORDER BY id
    LIMIT 100000
    FOR UPDATE SKIP LOCKED
)
UPDATE events
SET id_bigint = events.id
FROM batch
WHERE events.id = batch.id;
```


### Step 3a - Migration Pre Check
```sql
SELECT COUNT(*) FROM events WHERE id_bigint IS NULL;
-- should return 0

SELECT COUNT(*) FROM events WHERE id_bigint <> id;
-- should return 0
```

### Step 3b - Actual Migration
```sql
BEGIN;

-- Drop primary key constraint
ALTER TABLE events DROP CONSTRAINT events_pkey;

-- Drop id_bigint sync trigger
DROP TRIGGER IF EXISTS trigger_events_set_id_bigint ON events;
DROP FUNCTION IF EXISTS events_set_id_bigint_on_insert();

-- Rename columns
ALTER TABLE events RENAME COLUMN id TO id_old;
ALTER TABLE events RENAME COLUMN id_bigint TO id;

-- Recreate primary key on new `id`
ALTER TABLE events ADD PRIMARY KEY (id);

-- Update sequence ownership
ALTER TABLE events ALTER COLUMN id_old DROP DEFAULT;
ALTER SEQUENCE events_id_seq OWNED BY events.id;
ALTER TABLE events ALTER COLUMN id SET DEFAULT nextval('events_id_seq');

-- Ensure new inserts update `id_old`
CREATE OR REPLACE FUNCTION events_set_id_old_on_insert()
RETURNS TRIGGER AS $$
BEGIN
    NEW.id_old := NEW.id;
RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_events_set_id_old ON events;

CREATE TRIGGER trigger_events_set_id_old
    BEFORE INSERT ON events
    FOR EACH ROW
    EXECUTE FUNCTION events_set_id_old_on_insert();

COMMIT;
```

### Step 4 - Cleanup
```sql
BEGIN;
-- Drop old id_old column
ALTER TABLE events DROP COLUMN id_old;

-- Remove triggers and functions
DROP TRIGGER IF EXISTS trigger_events_set_id_old ON events;
DROP FUNCTION IF EXISTS events_set_id_old_on_insert();

COMMIT;
```

## References
WIP - e.g.:  
Migration scripts in the repository.  
Backfill script documentation.  
Trigger functions for PostgreSQL and MySQL.  

### Helpful Links
- [Stack Overflow: Migrating int to bigint](https://stackoverflow.com/questions/33504982/postgresql-concurrently-change-column-type-from-int-to-bigint)
- [Rollover](https://www.postgresql.org/message-id/10056.1057506282%40sss.pgh.pa.us)
- [PostgreSQL zero-downtime migration of a primary key from int to bigint (with Ruby on Rails specific notes)](https://engineering.silverfin.com/pg-zero-downtime-bigint-migration/)