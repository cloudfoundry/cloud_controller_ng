require 'spec_helper'

RSpec.describe 'Service account schema', isolation: :truncation do
  it 'allows reverting empty account assignments and restoring their foreign key' do
    db = Sequel::Model.db
    expect(db[:service_accounts].count).to eq(0)
    expect { Sequel::Migrator.run(db, DBMigrator::SEQUEL_MIGRATIONS, target: 20_261_005_120_000) }.not_to raise_error
    Sequel::Migrator.run(db, DBMigrator::SEQUEL_MIGRATIONS)
    expect(db.foreign_key_list(:apps)).to include(hash_including(columns: [:service_account_guid], table: :service_accounts))
    columns = db.schema(:service_accounts).to_h
    expect(columns).not_to have_key(:space_guid)
    expect(columns.fetch(:organization_id)[:allow_null]).to be(false)
    expect(columns.fetch(:identity_prefix)[:allow_null]).to be(false)
    expect(db.schema(:service_account_names).to_h).to have_key(:deleted_at)
  end
end
