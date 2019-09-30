require 'spec_helper'

RSpec.describe 'fill guid and timestamps for roles join tables', isolation: :truncation do
  let(:user) { VCAP::CloudController::User.make }
  let(:user_2) { VCAP::CloudController::User.make }
  let(:space) { VCAP::CloudController::Space.make }
  let(:tmp_migrations_dir) { Dir.mktmpdir }

  before do
    FileUtils.cp(
      File.join(DBMigrator::SEQUEL_MIGRATIONS, '20190924233211_fill_guid_and_timestamps_for_roles_join_tables.rb'),
      tmp_migrations_dir,
    )
  end

  before do
    [user, user_2].each do |user|
      space.organization.add_user(user)
      space.organization.add_billing_manager(user)
      space.organization.add_auditor(user)
      space.organization.add_manager(user)
      space.add_auditor(user)
      space.add_developer(user)
      space.add_manager(user)
    end
  end

  %w{
    organizations_auditors
    organizations_billing_managers
    organizations_managers
    organizations_users
    spaces_auditors
    spaces_developers
    spaces_managers
  }.each do |role_table|
    context role_table do
      it "fills in columns of the #{role_table} table" do
        Sequel::Migrator.run(VCAP::CloudController::DeploymentModel.db, tmp_migrations_dir, table: :my_fake_table)
        role = VCAP::CloudController::DeploymentModel.db[role_table.to_sym].first(user_id: user.id)
        role_2 = VCAP::CloudController::DeploymentModel.db[role_table.to_sym].first(user_id: user_2.id)

        expect(role[:guid]).to be_a_guid
        expect(role_2[:guid]).to be_a_guid
        expect(role[:guid] != role_2[:guid]).to be_truthy
        expect(role[:created_at]).to be_a(Time)
        expect(role[:updated_at]).to be_a(Time)
        expect(role[:updated_at] >= role[:created_at]).to be_truthy
      end
    end
  end
end
