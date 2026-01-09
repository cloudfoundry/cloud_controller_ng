require 'spec_helper'
require 'messages/route_update_message'

module VCAP::CloudController
  RSpec.describe RouteUpdateMessage do
    describe 'validations' do
      let(:params) do
        {
          metadata: {
            labels: { potato: 'yam' },
            annotations: { style: 'mashed' }
          }
        }
      end

      it 'accepts metadata params' do
        message = RouteUpdateMessage.new(params)
        expect(message).to be_valid
      end

      it 'accepts options: {}' do
        message = RouteUpdateMessage.new(params.merge(options: {}))
        expect(message).to be_valid
      end

      it 'accepts options params with round-robin load-balancing algorithm' do
        message = RouteUpdateMessage.new(params.merge(options: { loadbalancing: 'round-robin' }))
        expect(message).to be_valid
      end

      it 'accepts options params with least-connection load-balancing algorithm' do
        message = RouteUpdateMessage.new(params.merge(options: { loadbalancing: 'least-connection' }))
        expect(message).to be_valid
      end

      it 'does not accept options: nil' do
        message = RouteUpdateMessage.new(params.merge(options: nil))
        expect(message).not_to be_valid
        expect(message.errors.full_messages[0]).to include("Options 'options' is not a valid object")
      end

      it 'accepts loadbalancing: nil to unset load-balancing algorithm' do
        message = RouteUpdateMessage.new(params.merge(options: { loadbalancing: nil }))
        expect(message).to be_valid
      end

      it 'does not accept any other params' do
        message = RouteUpdateMessage.new(params.merge(unexpected: 'unexpected_value'))
        expect(message).not_to be_valid
        expect(message.errors.full_messages[0]).to include("Unknown field(s): 'unexpected'")
      end

      it 'does not accept unknown load-balancing algorithm' do
        message = RouteUpdateMessage.new(params.merge(options: { loadbalancing: 'cheesecake' }))
        expect(message).not_to be_valid
        expect(message.errors.full_messages[0]).to include("Options Loadbalancing must be one of 'round-robin, least-connection' if present")
      end

      it 'does not accept unknown option' do
        message = RouteUpdateMessage.new(params.merge(options: { gorgonzola: 'gouda' }))
        expect(message).not_to be_valid
        expect(message.errors.full_messages[0]).to include("Options Unknown field(s): 'gorgonzola'")
      end

      context 'when hash_based_routing feature flag is enabled' do
        before do
          VCAP::CloudController::FeatureFlag.make(name: 'hash_based_routing', enabled: true)
        end

        it 'does not accept hash_header longer than 128 characters' do
          message = RouteUpdateMessage.new(params.merge(options: { loadbalancing: 'hash', hash_header: 'X' * 129 }))
          expect(message).not_to be_valid
          expect(message.errors.full_messages[0]).to include('Hash header must be at most 128 characters')
        end

        it 'accepts hash_header exactly 128 characters' do
          message = RouteUpdateMessage.new(params.merge(options: { loadbalancing: 'hash', hash_header: 'X' * 128 }))
          expect(message).to be_valid
        end

        it 'does not accept hash_balance longer than 16 characters' do
          message = RouteUpdateMessage.new(params.merge(options: { loadbalancing: 'hash', hash_header: 'X-User-ID', hash_balance: '12345678901234567' }))
          expect(message).not_to be_valid
          expect(message.errors.full_messages[0]).to include('Hash balance must be at most 16 characters')
        end

        it 'accepts hash_balance exactly 16 characters' do
          message = RouteUpdateMessage.new(params.merge(options: { loadbalancing: 'hash', hash_header: 'X-User-ID', hash_balance: '9.9' }))
          expect(message).to be_valid
        end

        it 'does not accept hash_balance greater than 10.0' do
          message = RouteUpdateMessage.new(params.merge(options: { loadbalancing: 'hash', hash_header: 'X-User-ID', hash_balance: 10.1 }))
          expect(message).not_to be_valid
          expect(message.errors.full_messages[0]).to include('Hash balance must be either 0 or between 1.1 and 10.0')
        end

        it 'accepts hash_balance exactly 10.0' do
          message = RouteUpdateMessage.new(params.merge(options: { loadbalancing: 'hash', hash_header: 'X-User-ID', hash_balance: 10.0 }))
          expect(message).to be_valid
        end
      end
    end
  end
end
