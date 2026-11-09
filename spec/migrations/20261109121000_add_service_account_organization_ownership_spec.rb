require 'spec_helper'
require 'migrations/helpers/migration_shared_context'

RSpec.describe 'Service account organization ownership migration', isolation: :truncation, type: :migration do
  include_context 'migration' do
    let(:migration_filename) { '20261109121000_add_service_account_organization_ownership.rb' }
  end

  it 'backfills the owning org and initial entitlement without changing legacy identities or assigning prefixes' do
    space = create(:space)
    guid = SecureRandom.uuid
    now = Time.now.utc
    db[:service_account_names].insert(name: 'legacy-worker')
    db[:service_accounts].insert(guid: guid, name: 'legacy-worker', space_guid: space.guid, created_at: now, updated_at: now)

    Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true)

    account = db[:service_accounts].first(guid: guid)
    expect(account).to include(organization_id: space.organization_id, name: 'legacy-worker', space_guid: space.guid)
    expect(db[:service_account_space_entitlements].where(service_account_guid: guid, space_guid: space.guid).count).to eq(1)
    expect(db[:organizations].first(id: space.organization_id)[:service_account_prefix]).to be_nil
    expect(db[:service_account_names].where(name: 'legacy-worker').count).to eq(1)

    Sequel::Migrator.run(db, migrations_path, target: current_migration_index - 1, allow_missing_migration_files: true)
    expect(db[:service_accounts].first(guid: guid)).to include(name: 'legacy-worker', space_guid: space.guid)
    expect(db.table_exists?(:service_account_space_entitlements)).to be(false)
  end
end
