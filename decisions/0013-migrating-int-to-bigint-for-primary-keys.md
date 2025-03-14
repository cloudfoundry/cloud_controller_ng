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
- Ensure that migration only is executed when the new `id_bigint` column is fully populated.

The largest tables in a long-running foundation are `events`, `delayed_jobs`, `jobs`, and `app_usage_events`.

## Decisions

### Opt-Out Mechanism
Operators of smaller foundations, which are unlikely to ever encounter the integer overflow issue, may wish to avoid the risks and complexity associated with this migration.
They can opt out of the migration by setting the `skip_bigint_id_migration` flag in the CAPI-Release manifest.
When this flag is set, all migration steps will result in a no-op but will still be marked as applied in the `schema_versions` table.
*Important*: Removing the flag later will *not* re-trigger the migration. Operators must handle the migration manually if they choose to opt out.

### Scope

The `events` table will be migrated first as it has the most significant growth in `id` values.
Other tables will be migrated at a later stage.

### Newly Created Foundations
For newly created foundations, the `id` column for the `events` table will be created as `bigint` by default.
This will be implemented with migration step 1 and will be only applied, if the `events` table is empty.

### Phased Migration
The migration will be conducted in multiple steps to ensure minimal risk.
#### Step 1 - Preparation
- If the opt-out flag is set, this step will be a no-op.
- In case the target table is empty the type of the `id` column will be set to `bigint` directly.
- Otherwise, the following steps will be executed:
  - Add a new column `id_bigint` of type `bigint` to the target table. If the `id` column is referenced as a foreign key in other tables, also add an `<ref>_id_bigint` column in those referencing tables.
  - Create triggers to keep `id_bigint` in sync with `id` when new records are inserted.
  - Add constraints and indexes to `id_bigint` as required to match primary key and foreign key requirements.

#### Step 2 - Backfill
- Backfill will not be scheduled if the opt-out flag is set.
- If the `id_bigint` column does not exist, backfill will be skipped or result in a no-op.
- Use a batch-processing script (e.g. a delayed job) to populate `id_bigint` for existing rows in both the primary table and, if applicable, all foreign key references.
- Table locks will be avoided by using a batch processing approach.
- In case the table has a configurable cleanup duration, the backfill job will only process records which are beyond the cleanup duration to reduce the number of records to be processed. 
- Backfill will be executed outside the migration due to its potentially long runtime.
- If necessary the backfill will run for multiple weeks to ensure all records are processed.

#### Step 3 - Migration
- The migration is divided into two parts: a pre-check and the actual migration but both will be stored in a single migration script.
- This step will be a no-op if the opt-out flag is set or the `id` column is already of type `bigint`.
- All sql statements will be executed in a single transaction to ensure consistency.
##### Step 3a - Migration Pre Check
- In case the `id_bigint` column does not exist the migration will fail with a clear error message.
- Add a `CHECK` constraint to verify that `id_bigint` is fully populated (`id_bigint == id & id_bigint != NULL`).
- In case the backfill is not yet complete or the `id_bigint` column is not fully populated the migration will fail.
- If pre-check fails, operators might need to take manual actions to ensure all preconditions are met as the migration will be retried during the next deployment.
##### Step 3b - Actual Migration
- Remove the `CHECK` constraint once verified.
- Drop the primary key constraint on id.
- If foreign keys exist, drop the corresponding foreign key constraints.
- Remove the sync triggers.
- Drop the old `id` column.
- Rename the `id_bigint` column to `id`.
- Add PK constraint on `id` column and configure `id` generator.
- If foreign keys exist, rename `id_bigint` to `id` in referencing tables accordingly.

### Database Specifics

#### PostgreSQL
The default value of the `id` column could be either a sequence (for PostgreSQL versions < 10) or an identity column (for newer PostgreSQL versions).
This depends on the version of PostgreSQL which was used when the table was initially created.
The migration script needs to handle both cases.

#### MySQL
MySQL primary key changes typically cause table rebuilds due to clustered indexing, which can be expensive and disruptive, especially with clustered replication setups like Galera.
A common approach to mitigate this involves creating a new shadow table, performing a backfill, and then swapping tables atomically.  
Further details will be refined during implementation.

### Rollback Mechanism
The old `id` column is no longer retained, as the `CHECK` constraint ensures correctness during migration.
Step 3b (switch over) will be executed in a single transaction and will be rolled back if any issues occur.
If unexpected issues occur, the migration will fail explicitly, requiring intervention.
If rollback is needed, either backups could be restored or the migration needs to be reverted manually.

### Standardized Approach
Write reusable scripts for adding `id_bigint`, setting up triggers, backfilling data, and verifying migration readiness.
These scripts can be reused for other tables in the future.

### Release Strategy

Steps 1-2 will be released as a cf-deployment major release to ensure that the database is prepared for the migration.  
Steps 3-4 will be released as a subsequent cf-deployment major release to complete the migration.  
Between these releases there should be a reasonable time to allow the backfill to complete.

For the `events` table there is a default cleanup interval of 31 days. Therefore, for the `events` table the gap between the releases should be around 60 days.

## Consequences
### Positive Consequences

- Future-proofing the schema for tables with high record counts.
- Minimal locking during step 3b (actual migration) could result in slower queries or minimal downtime.
- A standardized process for similar migrations across the database.

### Negative Consequences

- Increased complexity in the migration process.
- Potentially long runtimes for backfilling data in case tables have millions of records.
- Requires careful coordination across multiple CAPI/CF-Deployment versions.
- If backfilling encounters edge cases (e.g., missing cleanup jobs), the migration may be delayed until operators intervene.

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


## Example Migration Scripts With PostgreSQL Syntax For `events` Table

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
ALTER TABLE events  ADD CONSTRAINT check_id_bigint_matches CHECK (id_bigint IS NOT NULL AND id_bigint = id);

-- Alternative:
SELECT COUNT(*) FROM events WHERE id_bigint IS DISTINCT FROM id;
-- should return 0
```

### Step 3b - Actual Migration
```sql
BEGIN;

ALTER TABLE events DROP CONSTRAINT check_id_bigint_matches;

-- Drop primary key constraint
ALTER TABLE events DROP CONSTRAINT events_pkey;

-- Drop id_bigint sync trigger
DROP TRIGGER IF EXISTS trigger_events_set_id_bigint ON events;
DROP FUNCTION IF EXISTS events_set_id_bigint_on_insert();

-- Drop the old id column
ALTER TABLE events DROP COLUMN id;

-- Rename columns
ALTER TABLE events RENAME COLUMN id_bigint TO id;

-- Recreate primary key on new `id`
ALTER TABLE events ADD PRIMARY KEY (id);

-- Set `id` as IDENTITY with correct starting value
DO $$ 
DECLARE max_id BIGINT;
BEGIN
SELECT COALESCE(MAX(id), 1) + 1 INTO max_id FROM events;

-- Set the column to IDENTITY with the correct start value
EXECUTE format(
        'ALTER TABLE events ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (START WITH %s)',
        max_id
        );

RAISE NOTICE 'Set id as IDENTITY starting from %', max_id;
END $$;

COMMIT;
```

### Helpful Commands
```sql
SELECT COUNT(*) FROM events WHERE id_bigint IS NULL;
-- should return 0

SELECT COUNT(*) FROM events WHERE id_bigint IS DISTINCT FROM id;
-- should return 0
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