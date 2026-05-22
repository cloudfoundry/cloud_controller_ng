require 'spec_helper'

RSpec.describe 'SpaceQuotaDefinitions' do
  let(:user) { create(:user) }
  let(:org) { create(:organization) }

  describe 'PUT /v2/space_quota_definitions/guid/spaces/space_guid' do
    context 'when the quota has a finite log rate limit and there are apps with unlimited log rates' do
      let(:admin_header) { headers_for(user, scopes: %w[cloud_controller.admin]) }
      let(:space_quota) { create(:space_quota_definition, organization: org, log_rate_limit: 100) }

      let!(:space) { create(:space, organization: org) }
      let!(:app_model) { create(:app_model, name: 'name1', space: space) }
      let!(:process_model) { create(:process_model, app: app_model, log_rate_limit: -1) }

      it 'returns 422' do
        put "/v2/space_quota_definitions/#{space_quota.guid}/spaces/#{space.guid}", nil, admin_header
        expect(last_response).to have_status_code(422)
        expect(decoded_response['error_code']).to eq('CF-UnprocessableEntity')
        expect(decoded_response['description']).to eq('Current usage exceeds new quota values. This space currently contains apps running with an unlimited log rate limit.')
      end
    end
  end
end
