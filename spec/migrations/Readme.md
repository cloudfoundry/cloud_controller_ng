# Sequel Migrations

Sequel migrations modify the database schema. To write high-quality migrations, it's important to observe several guidelines related to downtime, error handling, and transactional safety.

### Differences of supported DBs

At present, the Cloud Controller (CC) supports both Postgres and MySQL in various versions. Since these databases behave differently and offer different feature sets, it's necessary to reflect these differences in the migrations. Failing to do so may result in differing schemas for MySQL and Postgres after the same operation.

1. Postgres supports transactional DDL (Data Definition Language) statements but MySQL does not. This means when a failure occurs and a transaction is rolled back, only Postgres will correctly roll back the altered changes. MySQL commits every DDL statement immediately, which makes it impossible to roll back any schema change.
1. While Postgres automatically resets table locks on rollback or commit of a transaction, MySQL does not. If a migration that locks tables doesn't unlock them as part of error handling, MySQL can permanently block a table until it is manually unlocked again. Moreover, Sequel doesn't recognize how to lock tables, necessitating use of raw SQL queries, with differing syntaxes for both DBs.
1. If a MySQL table is locked and sub-queries are used, those sub-queries (alias them) must be named and locked, even if they don't exist at the time of locking.
1. When dropping columns, Postgres automatically drops all related indices and constraints entirely while MySQL only removes the affected columns from the index/constraint.
1. When renaming columns, both MySQL and Postgres auto-rename columns in indices. However, while Postgres cascades the rename into views, MySQL doesn't and the view still references the old column name, thus breaking it. Views thus must generally be dropped and recreated after renaming the column. Postgres just cascades a rename properly.
1. When changing the data type/field length of a column, Postgres doesn't permit this if a view includes this column. The view must firstly be dropped and recreated after modifying the column. MySQL properly cascades column data type/field length changes.
1. All constraints (views, indices, etc.) must be named. If not, MySQL and Postgres default to different constraint names, complicating future constraint editing.
1. While Postgres allows indices/constraints to incorporate unlimited-sized columns, MySQL doesn't. An index/constraint can hold columns (all combined) with a size of only [3072 bytes for InnoDB](https://dev.mysql.com/doc/refman/8.1/en/column-indexes.html). Plan accordingly for column sizes and their potential future use in a combined index/constraint. Reducing column sizes later is generally not feasible.
1. A size should always be specified for a string (and text should not be used). Postgres and MySQL have different size limits on String and TEXT fields. To ensure data can be migrated across the two databases (and others in future) without issues, a maximum size should always be specified. A rubocop linter has enforced this since 2017-07-30.
   1. For MySQL, `String` is `varchar(255)`, `String, text: true` has a max size of 16_000 for UTF-8-encoded DBs.
   1. For Postgres, both `String` and `String, text: true` are TEXT and have a max size of ~1GB.

### Rules when writing migrations

To create resilient and reliable migrations, follow these guidelines:

1. Do not use any Cloud Controller code in a migration. Changes in the model might modify old migrations and change their behavior and the behavior of their tests. Use raw Sequel operations instead, as you're aware of the exact database schema at that migration time. For instance, if you use a model in a migration and a later migration changes that model's table name, the initial migration would fail because the table does not yet exist when the migration runs and uses the model from the CC's codebase.
1. Aim to write separate [up and down](https://sequel.jeremyevans.net/rdoc/files/doc/migration_rdoc.html#top) Sequel migrations. The `change do` command automatically generates the down part but occasionally behaves unpredictably and isn't always able to compute the opposite of what the migration accomplished. By defining `up do` and `down do` separately, you'll have full control over the down part.
1. Opt for a larger number of smaller transactions in migrations rather than larger transactions. If a single change fails, the entire migration must be manually rolled back. Atomic migrations are easier to roll back. Each migration runs in a database synchronisation call.
1. Write idempotent migrations. Even though a row in the database prevents a migration from running twice, you can't be sure the database remains unchanged after an error in the migration since schema changes can't always be transactionally rolled back e.g. on MySQL. Make your migrations rerunnable. This often isn't the case when using Sequel functions with default values. For instance, [drop_index](https://www.rubydoc.info/github/jeremyevans/sequel/Sequel%2FSchema%2FAlterTableGenerator:drop_index) by default throws an error if an index you want to drop has already been dropped. In a migration, you'll want to pass the optional parameter `if_exists: true` so the statement is idempotent and if a migration fails in the middle, it can be rerun. Sometimes you will also find different functions that offer idempotency. Like `create_table` (just create table), `create_table!` (drop in any case and create table) and `create_table?` (create table if not already exists) so also look out for such options. In case the needed Sequel function does not offer a parameter/function for idempotency, one must test against the schema and just run statements conditionally. E.g. check if an index already exists with `... if self.indexes(:my_table)[:my_index].nil?` before creating it.
1. During migrations that execute DML (Data Manipulation Language) statements, consider locking the table while altering data. For instance, if you're removing duplicates and setting a unique constraint, you must prevent new inserts while the migration runs. Otherwise, setting the unique constraint later could fail. Note that Sequel doesn't offer built-in functions for table locks, so you'll need to use raw SQL queries that vary depending on the Database backend they run on.
1. Separate data-changing migrations from schema-changing DDL statements to leverage at least the database rollback function for DML Statements. Explicitly wrap data changes in a transaction that doesn't include DDL statements. Avoid including DDL in that transaction otherwise MySQL will autocommit data changes and a rollback is impossible.
1. Try to handle DML (Data Manipulation Language) statements entirely within the DB, avoiding any looping over returned data in the migration process. This helps to reduce the time a table is locked. For example, instead of finding all duplicates with a select and then iterating over the results in Ruby and deleting the rows, use a subquery to let the DB perform the heavy lifting. Since these operations should be performed with a table lock to prevent new duplicates, it is advantageous to minimize runtime as much as possible. Involving Ruby and dealing with large tables could increase runtimes to several minutes, leading to locked API requests and potential unavailability.
   ```ruby
   min_ids_subquery = self.from(:mytable___subquery).
                        select(Sequel.function(:MIN, :id).as(:min_id)).
                        group_by(:field_a, :field_b)
   self[:mytable].exclude(id: min_ids_subquery).delete
   ```
1. If you're changing multiple tables in one migration, open a separate transaction for each table. Otherwise, you lock all the tables at once, increasing the likelihood of mutually locking between two or more operations on the database (a deadlock situation). The migration might lock tables that a join select statement needs, but that select statement has already locked other tables required for the migration. As a result, the DB typically aborts both queries, leading to a failed API request and a failed transaction. An `up/down/change do` block automatically begins a transaction for its entire block. You must disable this by calling `no_transaction`. Then, place each table in its own `transaction do` block inside the `up/down/change do` block. Now, each table has its own transaction, avoiding multiple table locks in a single transaction and thereby preventing possible deadlocks.
   ```ruby
   Sequel.migration do
     annotation_tables = %w[
       app_annotations
       build_annotations
       ...
     ].freeze

     no_transactions # IMPORTANT: DISABLE AUTOMATIC TRANSACTION MANAGEMENT BY UP/DOWN/CHANGE BLOCKS.

     up do
       annotation_tables.each do |table|
         transaction do # DO NOT FORGET THIS TRANSACTION INSIDE THE LOOP OTHERWISE YOU LOCK MANY TABLES IN A SINGLE TRANSACTION
            alter_table(table.to_sym) do
            ...
            end
         end
       end
     end
     down do
       annotation_tables.each do |table|
         transaction do # DO NOT FORGET THIS TRANSACTION INSIDE THE LOOP OTHERWISE YOU LOCK MANY TABLES IN A SINGLE TRANSACTION
            alter_table(table.to_sym) do
            ...
            end
         end
       end
     end
   end
   ```
1. If you're writing a uniqueness constraint where some of the values can be null, remember that `null != null`. For instance, the values `[1, 1, null]` and `[1, 1, null]` are considered unique. Uniqueness constraints only work on columns that do not allow `NULL` as a value. If this is the case, change the column to disallow `NULL` and set the default to an empty string instead.
1. If you need to execute different operations for MySQL and Postgres, you can check the database type as follows: `... if database_type == :postgres` or `... if database_type == :mysql`.

# Sequel Migration Tests

Sequel migration tests have a distinct operation compared to conventional RSpec tests. Primarily, they execute the Down migration and restore the database state to its previous form before the test-specific migration was carried out. The process includes running a test, creating assets, executing a specific migration file for testing, and asserting certain behaviors. However, be aware that Sequel migration tests impose specific limitations and requirements on test writing.

1. The migration spec should not be influenced by any Cloud Controller code. This requirement is the same as for the migration itself. Any model changes can modify the old migrations and alter the behaviors and results of the tests. Therefore, don't select data via the CC models, instead make the selects in raw Sequel and assert the behavior you'd like to test.
1. It's recommended to use the `migration` shared context, as it ensures that the database schema first reverts to the version before the migration you aim to test. This shared context also provides a directory containing a single migration for running a particular migration within a test. When the test is done, this shared context makes sure to restore the correct schema by running the migrations that post-date the one being tested. Thus, avoiding cases of a half-migrated database that could result in random test failures. It also makes sure to test not every migration that comes after the test migration, but just a single migration is executed and then the expected behavior is evaluated.

### Usage

Here’s a guide on how to write a migration spec. The `migration` shared context uses the `migration_file` variable, containing the filename of the migration under review. This shared context also provides a `migration_to_test` variable to perform the specific migration. All other processes, including migrating one version before the test migration and fully migrating the table after the test has finished, are handled automatically.

```ruby
require 'spec_helper'
require 'migrations/helpers/migration_shared_context'

RSpec.describe 'migration to modify isolation_segments', isolation: :truncation do
  include_context 'migration' do
    let(:migration_filename) { '20230822153000_isolation_segments_modify.rb' }
  end

  describe 'isolation_segments table' do
    it 'retains the initial name and guid' do
      db[:isolation_segments].insert(name: 'bommel', guid: '123')
      a1 = db[:isolation_segment_annotations].first(resource_guid: '123')
      expect { Sequel::Migrator.run(db, migration_to_test, allow_missing_migration_files: true) }.not_to raise_error
      b1 = db[:isolation_segment_annotations].first(resource_guid: '123')
      expect(b1[:guid]).to eq a1[:guid]
      expect(b1[:name]).to eq a1[:name]
    end
  end
end
```

The code mentioned above tests a migration that alters the isolation_segments table. It confirms that the initial name and guid remain intact even after the migration operation. Note that in this scenario, the CC models are not used. Instead, the selects and inserts are performed directly with Sequel, keeping in mind the schema that exists before and after the migration. This approach ensures accuracy, and the test will continue to work even if later migrations alter the table, CC code and models, or even drop tables, etc. Essentially, the migration is tested in the state that the DB was in at the time of writing the migration.
