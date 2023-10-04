require 'spec_helper'

RSpec.describe 'fill role_guid and timestamps for spaces_auditors table', isolation: :truncation do
  let(:role_table) { :spaces_auditors }
  let(:filename) { '20191218001006_fill_guid_and_timestamps_for_spaces_auditors.rb' }

  let(:db) { Sequel::Model.db }
  let(:user) { VCAP::CloudController::User.make }
  let(:user_2) { VCAP::CloudController::User.make }
  let(:user_3) { VCAP::CloudController::User.make }
  let(:space) { VCAP::CloudController::Space.make }
  let(:tmp_migrations_dir) { Dir.mktmpdir }

  before do
    FileUtils.cp(File.join(DBMigrator::SEQUEL_MIGRATIONS, filename), tmp_migrations_dir)
    [user, user_2].each do |user|
      db[role_table].insert({ user_id: user.id, space_id: space.id })
    end

    db[role_table].insert({ user_id: user_3.id, space_id: space.id, role_guid: 'existing-role-guid' })
  end

  it 'fills in columns of the spaces_auditors table' do
    Sequel::Migrator.run(db, tmp_migrations_dir, table: :my_fake_table)
    role = db[role_table].first(user_id: user.id)
    role_2 = db[role_table].first(user_id: user_2.id)
    role_3 = db[role_table].first(user_id: user_3.id)

    expect(role[:role_guid]).to be_a_guid
    expect(role_2[:role_guid]).to be_a_guid
    expect(role_3[:role_guid]).to eq('existing-role-guid')

    expect(role[:role_guid] != role_2[:role_guid]).to be_truthy
    expect(role[:created_at]).to be_a(Time)
    expect(role[:updated_at]).to be_a(Time)
    expect(role[:updated_at] >= role[:created_at]).to be_truthy
  end
end
