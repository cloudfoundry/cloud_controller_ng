require 'migration_spec_helper'

RSpec.describe 'fill role_guid and timestamps for spaces_auditors table', isolation: :truncation, type: :migration do
  let(:role_table) { :spaces_auditors }
  let(:filename) { '20191218001006_fill_guid_and_timestamps_for_spaces_auditors.rb' }

  let(:db) { Sequel::Model.db }
  let(:quota_def_id) do
    db[:quota_definitions].insert(guid: SecureRandom.uuid, name: "quota-#{SecureRandom.uuid}",
                                  non_basic_services_allowed: false, total_services: -1, memory_limit: 0, total_routes: -1)
  end
  let(:org_id) do
    db[:organizations].insert(guid: SecureRandom.uuid, name: "org-#{SecureRandom.uuid}",
                              quota_definition_id: quota_def_id)
  end
  let(:space_id) do
    db[:spaces].insert(guid: SecureRandom.uuid, name: "space-#{SecureRandom.uuid}", organization_id: org_id)
  end
  let(:user_id)   { db[:users].insert(guid: SecureRandom.uuid) }
  let(:user_2_id) { db[:users].insert(guid: SecureRandom.uuid) }
  let(:user_3_id) { db[:users].insert(guid: SecureRandom.uuid) }
  let(:tmp_migrations_dir) { Dir.mktmpdir }

  before do
    FileUtils.cp(File.join(DBMigrator::SEQUEL_MIGRATIONS, filename), tmp_migrations_dir)
    db[role_table].insert({ user_id: user_id, space_id: space_id })
    db[role_table].insert({ user_id: user_2_id, space_id: space_id })
    db[role_table].insert({ user_id: user_3_id, space_id: space_id, role_guid: 'existing-role-guid' })
  end

  it 'fills in columns of the spaces_auditors table' do
    Sequel::Migrator.run(db, tmp_migrations_dir, table: :my_fake_table)
    role   = db[role_table].first(user_id: user_id)
    role_2 = db[role_table].first(user_id: user_2_id)
    role_3 = db[role_table].first(user_id: user_3_id)

    expect(role[:role_guid]).to be_a_guid
    expect(role_2[:role_guid]).to be_a_guid
    expect(role_3[:role_guid]).to eq('existing-role-guid')

    expect(role[:role_guid] != role_2[:role_guid]).to be_truthy
    expect(role[:created_at]).to be_a(Time)
    expect(role[:updated_at]).to be_a(Time)
    expect(role[:updated_at] >= role[:created_at]).to be_truthy
  end
end
