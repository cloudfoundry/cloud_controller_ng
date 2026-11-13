require 'spec_helper'

RSpec.describe 'app service account relationship migration recovery', isolation: :truncation, type: :migration do
  it 'resumes after index creation failure and preserves an already valid index' do
    db = Sequel::Model.db
    load File.join(DBMigrator::SEQUEL_MIGRATIONS, '20261005120100_add_app_service_account.rb')
    migration = Sequel::Migration.descendants.last
    migration.apply(db, :down)
    allow(db).to receive(:add_index).and_call_original
    allow(db).to receive(:add_index).with(:apps, :service_account_guid, anything).and_raise(Sequel::DatabaseError, 'index creation interrupted')

    expect { migration.apply(db, :up) }.to raise_error(Sequel::DatabaseError, 'index creation interrupted')
    expect(db.schema(:apps).to_h).to have_key(:service_account_guid)
    expect(db.foreign_key_list(:apps)).to include(hash_including(name: :fk_apps_service_account_guid))
    allow(db).to receive(:add_index).and_call_original

    expect { migration.apply(db, :up) }.not_to raise_error
    expect(db.indexes(:apps)).to have_key(:apps_service_account_guid_index)
    expect(db).not_to receive(:add_index)
    expect(db).not_to receive(:drop_index)
    expect { migration.apply(db, :up) }.not_to raise_error
  ensure
    allow(db).to receive(:add_index).and_call_original
    allow(db).to receive(:drop_index).and_call_original
    migration.apply(db, :up) unless db.indexes(:apps).key?(:apps_service_account_guid_index)
  end

  it 'rebuilds an invalid PostgreSQL concurrent index' do
    db = Sequel::Model.db
    skip 'PostgreSQL concurrent index validity' unless db.database_type == :postgres

    load File.join(DBMigrator::SEQUEL_MIGRATIONS, '20261005120100_add_app_service_account.rb')
    migration = Sequel::Migration.descendants.last
    db.run("UPDATE pg_index SET indisvalid = false WHERE indexrelid = 'apps_service_account_guid_index'::regclass")

    migration.apply(db, :up)

    expect(db.fetch("SELECT indisvalid FROM pg_index WHERE indexrelid = 'apps_service_account_guid_index'::regclass").get(:indisvalid)).to be(true)
  ensure
    db.run("UPDATE pg_index SET indisvalid = true WHERE indexrelid = 'apps_service_account_guid_index'::regclass") if db&.database_type == :postgres
  end
end
