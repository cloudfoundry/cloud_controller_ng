require 'rails_helper'
require 'permissions_spec_helper'

RSpec.describe AppUsageConsumersController, type: :controller do
  describe '#index' do
    let(:user) { VCAP::CloudController::User.make }
    let!(:app_usage_consumer_1) do
      event = VCAP::CloudController::AppUsageEvent.make
      VCAP::CloudController::AppUsageConsumer.make(
        consumer_guid: 'consumer-1',
        last_processed_guid: event.guid
      )
    end
    let!(:app_usage_consumer_2) do
      event = VCAP::CloudController::AppUsageEvent.make
      VCAP::CloudController::AppUsageConsumer.make(
        consumer_guid: 'consumer-2',
        last_processed_guid: event.guid
      )
    end

    before do
      set_current_user(user)
    end

    context 'when the user is not an admin' do
      it 'returns an empty list' do
        get :index

        expect(response.status).to eq(200)
        expect(parsed_body['resources']).to be_empty
      end
    end

    context 'when the user is an admin' do
      before do
        set_current_user_as_admin(user:)
      end

      it 'returns all app usage consumers' do
        get :index

        expect(response.status).to eq(200)
        expect(parsed_body['resources'].length).to eq(2)
        expect(parsed_body['resources'][0]['guid']).to eq('consumer-1')
        expect(parsed_body['resources'][1]['guid']).to eq('consumer-2')
      end

      context 'when filtering by consumer_guids' do
        it 'returns filtered consumers' do
          get :index, params: { consumer_guids: 'consumer-1' }

          expect(response.status).to eq(200)
          expect(parsed_body['resources'].length).to eq(1)
          expect(parsed_body['resources'][0]['guid']).to eq('consumer-1')
        end
      end

      context 'when filtering by last_processed_guids' do
        it 'returns filtered consumers' do
          get :index, params: { last_processed_guids: app_usage_consumer_1.last_processed_guid }

          expect(response.status).to eq(200)
          expect(parsed_body['resources'].length).to eq(1)
          expect(parsed_body['resources'][0]['guid']).to eq('consumer-1')
        end
      end
    end
  end

  describe '#show' do
    let(:user) { VCAP::CloudController::User.make }
    let!(:app_usage_consumer) do
      event = VCAP::CloudController::AppUsageEvent.make
      VCAP::CloudController::AppUsageConsumer.make(
        consumer_guid: 'consumer-1',
        last_processed_guid: event.guid
      )
    end

    before do
      set_current_user(user)
    end

    context 'when the user is not an admin' do
      it 'returns 404' do
        get :show, params: { guid: app_usage_consumer.consumer_guid }

        expect(response.status).to eq(404)
      end
    end

    context 'when the user is an admin' do
      before do
        set_current_user_as_admin(user:)
      end

      it 'returns the requested app usage consumer' do
        get :show, params: { guid: app_usage_consumer.consumer_guid }

        expect(response.status).to eq(200)
        expect(parsed_body['guid']).to eq(app_usage_consumer.consumer_guid)
        expect(parsed_body['last_processed_guid']).to eq(app_usage_consumer.last_processed_guid)
      end

      it 'returns 404 when the consumer does not exist' do
        get :show, params: { guid: 'nonexistent-guid' }

        expect(response.status).to eq(404)
      end
    end
  end

  describe '#destroy' do
    let(:user) { VCAP::CloudController::User.make }
    let!(:app_usage_consumer) do
      event = VCAP::CloudController::AppUsageEvent.make
      VCAP::CloudController::AppUsageConsumer.make(
        consumer_guid: 'consumer-1',
        last_processed_guid: event.guid
      )
    end

    before do
      set_current_user(user)
    end

    context 'when the user is not an admin' do
      it 'returns 403' do
        delete :destroy, params: { guid: app_usage_consumer.consumer_guid }

        expect(response.status).to eq(403)
      end
    end

    context 'when the user is an admin' do
      before do
        set_current_user_as_admin(user:)
      end

      it 'deletes the app usage consumer' do
        expect do
          delete :destroy, params: { guid: app_usage_consumer.consumer_guid }
        end.to change(VCAP::CloudController::AppUsageConsumer, :count).by(-1)

        expect(response.status).to eq(204)
      end

      it 'returns 404 when the consumer does not exist' do
        delete :destroy, params: { guid: 'nonexistent-guid' }

        expect(response.status).to eq(404)
      end
    end
  end
end
