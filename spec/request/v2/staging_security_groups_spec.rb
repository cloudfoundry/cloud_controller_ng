require 'spec_helper'

RSpec.describe 'Staging Security Groups' do
  describe 'PUT /v2/spaces/:guid/staging_security_groups/:security_group_guid' do
    let(:org) { VCAP::CloudController::Organization.make }
    let(:space) { VCAP::CloudController::Space.make(organization: org) }
    let(:security_group) { VCAP::CloudController::SecurityGroup.make }
    let(:user) { VCAP::CloudController::User.make }

    before do
      space.organization.add_user(user)
      space.add_manager(user)
    end

    it 'associates the security group with the space during staging' do
      put "/v2/spaces/#{space.guid}/staging_security_groups/#{security_group.guid}", nil, headers_for(user)

      expect(last_response.status).to eq(201)

      security_group.reload
      space.reload
      expect(space.staging_security_groups).to include(security_group)
      expect(security_group.staging_spaces).to include(space)
    end
  end

  describe 'DELETE /v2/spaces/:guid/staging_security_groups/:security_group_guid' do
    let(:org) { VCAP::CloudController::Organization.make }
    let(:space) { VCAP::CloudController::Space.make(organization: org) }
    let(:security_group) { VCAP::CloudController::SecurityGroup.make }
    let(:user) { VCAP::CloudController::User.make }

    before do
      space.organization.add_user(user)
      space.add_manager(user)

      space.add_staging_security_group(security_group)
    end

    it 'removes the association' do
      expect(space.staging_security_groups).to include(security_group)
      delete "/v2/spaces/#{space.guid}/staging_security_groups/#{security_group.guid}", nil, headers_for(user)
      expect(last_response.status).to eq(204)

      space.reload
      security_group.reload
      expect(security_group.staging_spaces).not_to include(space)
      expect(space.staging_security_groups).not_to include(security_group)
    end
  end

  describe 'PUT /v2/security_groups/:guid/staging_spaces/:space_guid' do
    let(:org) { VCAP::CloudController::Organization.make }
    let(:space) { VCAP::CloudController::Space.make(organization: org) }
    let(:security_group) { VCAP::CloudController::SecurityGroup.make }
    let(:user) { VCAP::CloudController::User.make }

    before do
      space.organization.add_user(user)
      space.add_manager(user)
    end

    it 'associates the security group with the space during staging' do
      put "/v2/security_groups/#{security_group.guid}/staging_spaces/#{space.guid}", nil, admin_headers_for(user)
      expect(last_response.status).to eq(201)

      security_group.reload
      space.reload
      expect(security_group.staging_spaces).to include(space)
      expect(space.staging_security_groups).to include(security_group)
    end
  end

  describe 'DELETE /v2/security_groups/:guid/staging_spaces/:space_guid' do
    let(:org) { VCAP::CloudController::Organization.make }
    let(:space) { VCAP::CloudController::Space.make(organization: org) }
    let(:security_group) { VCAP::CloudController::SecurityGroup.make }
    let(:user) { VCAP::CloudController::User.make }

    before do
      space.organization.add_user(user)
      space.add_manager(user)

      security_group.add_staging_space(space)
    end

    it 'associates the security group with the space during staging' do
      expect(security_group.staging_spaces).to include(space)
      expect(space.staging_security_groups).to include(security_group)

      delete "/v2/security_groups/#{security_group.guid}/staging_spaces/#{space.guid}", nil, admin_headers_for(user)
      expect(last_response.status).to eq(204)

      security_group.reload
      space.reload
      expect(security_group.staging_spaces).not_to include(space)
      expect(space.staging_security_groups).not_to include(security_group)
    end
  end
end
