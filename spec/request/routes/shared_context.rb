require 'presenters/v3/space_presenter'
require 'presenters/v3/organization_presenter'

RSpec.shared_context 'routes request spec' do
  let(:user) { VCAP::CloudController::User.make }
  let(:admin_header) { admin_headers_for(user) }
  let!(:org) { VCAP::CloudController::Organization.make(created_at: 1.hour.ago) }
  let!(:space) { VCAP::CloudController::Space.make(name: 'a-space', created_at: 1.hour.ago, organization: org) }

  let(:space_json_generator) do
    lambda { |s|
      presented_space = VCAP::CloudController::Presenters::V3::SpacePresenter.new(s).to_hash
      presented_space[:created_at] = iso8601
      presented_space[:updated_at] = iso8601
      presented_space
    }
  end

  let(:org_json_generator) do
    lambda { |o|
      presented_space = VCAP::CloudController::Presenters::V3::OrganizationPresenter.new(o).to_hash
      presented_space[:created_at] = iso8601
      presented_space[:updated_at] = iso8601
      presented_space
    }
  end

  before do
    TestConfig.override(kubernetes: {})
  end
end
