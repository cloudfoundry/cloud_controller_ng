require 'spec_helper'

RSpec.describe 'fill role_guid and timestamps for roles join tables', isolation: :truncation do
  let(:db) { Sequel::Model.db }
  let(:user) { VCAP::CloudController::User.make }
  let(:user_2) { VCAP::CloudController::User.make }
  let(:space) { VCAP::CloudController::Space.make }
  let(:tmp_migrations_dir) { Dir.mktmpdir }

  org_roles = %w{
    organizations_auditors
    organizations_billing_managers
    organizations_managers
    organizations_users
  }
  space_roles = %w{
    spaces_auditors
    spaces_developers
    spaces_managers
  }
  roles = org_roles + space_roles

  before do
    FileUtils.cp(
      File.join(DBMigrator::SEQUEL_MIGRATIONS, '20191014233211_fill_guid_and_timestamps_for_roles_join_tables.rb'),
      tmp_migrations_dir,
    )
  end

  before do
    [user, user_2].each do |user|
      space_roles.each { |s_role|
        db[s_role.to_sym].insert({
          user_id: user.id,
          space_id: space.id
        })
      }

      org_roles.each { |o_role|
        db[o_role.to_sym].insert({
          user_id: user.id,
          organization_id: space.organization.id
        })
      }
    end
  end

  roles.each do |role_table|
    context role_table do
      it "fills in columns of the #{role_table} table" do
        Sequel::Migrator.run(db, tmp_migrations_dir, table: :my_fake_table)
        role = db[role_table.to_sym].first(user_id: user.id)
        role_2 = db[role_table.to_sym].first(user_id: user_2.id)

        expect(role[:role_guid]).to be_a_guid
        expect(role_2[:role_guid]).to be_a_guid
        expect(role[:role_guid] != role_2[:role_guid]).to be_truthy
        expect(role[:created_at]).to be_a(Time)
        expect(role[:updated_at]).to be_a(Time)
        expect(role[:updated_at] >= role[:created_at]).to be_truthy
      end
    end
  end
end
