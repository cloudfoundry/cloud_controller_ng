require 'rails_helper'
require 'permissions_spec_helper'

RSpec.describe ServiceBrokersController, type: :controller do
  describe '#index' do
    let(:user) { VCAP::CloudController::User.make }
    let!(:service_broker_1) { VCAP::CloudController::ServiceBroker.make }

    before do
      set_current_user(user)
      allow_user_global_read_access(user)
    end

    context 'when the user has global read access' do
      it 'returns 200 and lists all service brokers' do
        get :index

        response_guids = parsed_body['resources'].map { |r| r['guid'] }
        expect(response.status).to eq 200
        expect(response_guids).to match_array([service_broker_1].map(&:guid))
      end
    end

    context 'when the user does not have read scope' do
      before do
        set_current_user(VCAP::CloudController::User.make, scopes: ['cloud_controller.write'])
      end

      it 'raises an ApiError with a 403 code' do
        get :index

        expect(response.status).to eq 403
        expect(response.body).to include 'NotAuthorized'
      end
    end
  end
end
