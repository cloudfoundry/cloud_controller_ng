require 'spec_helper'

RSpec.describe 'Service account namespace rollback', isolation: :truncation do
  it 'allows reverting an empty namespace transition' do
    db = Sequel::Model.db
    expect(db[:service_accounts].count).to eq(0)
    expect { Sequel::Migrator.run(db, DBMigrator::SEQUEL_MIGRATIONS, target: 20_261_109_122_999) }.not_to raise_error
    Sequel::Migrator.run(db, DBMigrator::SEQUEL_MIGRATIONS)
  end

  it 'allows reverting an empty transition after MySQL has selected the composite index for the org foreign key' do
    db = Sequel::Model.db
    skip 'MySQL chooses foreign-key supporting indexes' unless db.database_type == :mysql

    db.alter_table(:service_accounts) do
      drop_foreign_key [:organization_id], name: :fk_service_accounts_organization
      drop_index :organization_id, name: :fk_service_accounts_organization, concurrently: false if db.indexes(:service_accounts).key?(:fk_service_accounts_organization)
      add_foreign_key [:organization_id], :organizations, name: :fk_service_accounts_organization
    end

    expect { Sequel::Migrator.run(db, DBMigrator::SEQUEL_MIGRATIONS, target: 20_261_109_122_999) }.not_to raise_error
    Sequel::Migrator.run(db, DBMigrator::SEQUEL_MIGRATIONS)
  end

  it 'allows reverting empty account assignments and restoring their foreign key' do
    db = Sequel::Model.db
    expect { Sequel::Migrator.run(db, DBMigrator::SEQUEL_MIGRATIONS, target: 20_261_005_120_000) }.not_to raise_error
    Sequel::Migrator.run(db, DBMigrator::SEQUEL_MIGRATIONS)
    expect(db.foreign_key_list(:apps)).to include(hash_including(columns: [:service_account_guid], table: :service_accounts))
  end
end
