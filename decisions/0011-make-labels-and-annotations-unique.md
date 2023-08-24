11: Adding key prefix to annotations
================================

Date: 2023-08-23

Status
------

Accepted

Context
-------

The database for labels and annotation tables currently lacks unique constraints, which can lead to the potential insertion of duplicate metadata (labels/annotations) due to a race condition. This occurs when two CC VMs receive an update request concurrently, find no existing metadata object in the table, and subsequently, both issue a create. Given the absence of preventative measures in the DB schema, this results in duplicate entries (sometimes with differing values) in the database, leading to undefined behavior.
The inconsistency in the metadata can cause the API to return different results for different calls. To ensure data integrity and consistency, it is crucial to prevent duplicates in the database for metadata objects.
Our proposed solution is to set a unique constraint on labels(resource_id, key_prefix, key_name) and annotations(resource_id, key_prefix, key). However, there are several non-obvious considerations related to Postgres and MySQL behavior.

1. `NULL` values in the database (both MySQL and Postgres) are always unique as `NULL!=NULL` in SQL. To make the unique constraint effective, we must not allow `NULL` values.
1. The Key column in the Annotations Tables is of type `varchar(1000)`. This length is too long for MySQL to create a unique constraint on it. As the API docs and the CC limit the key length for annotations to 63 characters, adjusting this column's length is advantageous.
1. During the removal of duplicates from the metadata tables, it is critical to ensure no new duplicates are inserted while the DB migration runs. Otherwise, it would fail setting the unique constraint. We need to use table locking during a table's migration.

Decision
--------

1. We will modify the CC Code to insert an empty string into the database but convert this to nil in the Model to maintain current behavior and not to have compare string values. The CC can handle both an empty string in the columns `key_prefix` and `key` columns and the `NULL` value at this point.
1. We will add code in the CC to manage unique constraint violations when updating labels/annotations and retry once to eliminate the race condition and ensure a select returns a valid object, thereby preventing a second create on a metadata table.
1. We will introduce a migration that modifies the schema and sanitizes the metadata tables:
   1. For Annotations Tables:
      1. Lock the Table
      1. Trim Keys longer than 63 characters (this should never actually occur, but is done to prevent migration failure)
      1. Reduce the Column Length of the Key column to 63 characters
      1. Convert all `NULL` values in the `key_prefix` column to an empty string
      1. Set a NOT `NULL` constraint on columns (resource_id, key_prefix, key)
      1. Find and delete all duplicate values where the columns (resource_id, key_prefix, key) are equal
      1. Set a unique constraint for columns (resource_id, key_prefix, key)
   1. For Labels Tables:
      1. Lock the Table
      1. Convert all `NULL` values in the `key_prefix` column to an empty string
      1. Set a NOT `NULL` constraint on columns (resource_id, key_prefix, key_name)
      1. Find and delete all duplicate values where the columns (resource_id, key_prefix, key_name) are equal
      1. Set a unique constraint for columns (resource_id, key_prefix, key_name)
1. We will modify the code to clean up and stop handling `NULL` values from the DB as the can just be empty strings in the DB at this point.

Please note:
1. Steps 1 and 2 are backward compatible with any CC version.
1. Steps 3 and 4 are backward compatible with any CC version that includes the changes from Step 1 and 2.

Consequences
------------

### Positive Consequences

1. The API will behave correctly as duplicates will no longer occur.

### Negative Consequences

1. A staged rollout will be necessary, requiring clear documentation about limitations on upgrade paths, as we have two changes that necessitate a specific minimum CF-Deployment/CAPI version.