require 'spec_helper'

RSpec.describe 'add role_guid and timestamps to roles join tables', isolation: :truncation do
  let(:db) { Sequel::Model.db }
  let(:user) { VCAP::CloudController::User.make }
  let(:space) { VCAP::CloudController::Space.make }
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

  before do
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

  roles = org_roles + space_roles

  roles.each do |role_table|
    context role_table do
      it "adds the columns to the #{role_table} table" do
        role = db[role_table.to_sym].first(user_id: user.id)

        expect(role[:role_guid]).to be_nil
        expect(role[:created_at]).to be_a(Time)
        expect(role[:updated_at]).to be_a(Time)
      end
    end
  end
end
