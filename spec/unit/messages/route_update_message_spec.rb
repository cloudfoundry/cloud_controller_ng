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

      context 'with hash-based routing feature enabled' do
        before do
          VCAP::CloudController::FeatureFlag.make(name: 'hash_based_routing', enabled: true)
        end

        it 'accepts options params with hash load-balancing algorithm' do
          message = RouteUpdateMessage.new(params.merge(options: { loadbalancing: 'hash', hash_header: 'X-User-ID' }))
          expect(message).to be_valid
        end

        it 'accepts options params with hash algorithm and hash_balance' do
          message = RouteUpdateMessage.new(params.merge(options: { loadbalancing: 'hash', hash_header: 'X-User-ID', hash_balance: 1.5 }))
          expect(message).to be_valid
        end

        it 'accepts hash_balance as string' do
          message = RouteUpdateMessage.new(params.merge(options: { loadbalancing: 'hash', hash_header: 'X-User-ID', hash_balance: '1.5' }))
          expect(message).to be_valid
        end

        it 'does not accept hash algorithm without hash_header' do
          message = RouteUpdateMessage.new(params.merge(options: { loadbalancing: 'hash' }))
          expect(message).not_to be_valid
          expect(message.errors.full_messages[0]).to include('Options Hash header must be present when loadbalancing is set to hash')
        end

        it 'does not accept hash_header for non-hash algorithm' do
          message = RouteUpdateMessage.new(params.merge(options: { loadbalancing: 'round-robin', hash_header: 'X-User-ID' }))
          expect(message).not_to be_valid
          expect(message.errors.full_messages[0]).to include('Options Hash header can only be set when loadbalancing is hash')
        end

        it 'does not accept hash_balance for non-hash algorithm' do
          message = RouteUpdateMessage.new(params.merge(options: { loadbalancing: 'round-robin', hash_balance: 1.0 }))
          expect(message).not_to be_valid
          expect(message.errors.full_messages[0]).to include('Options Hash balance can only be set when loadbalancing is hash')
        end

        it 'does not accept negative hash_balance' do
          message = RouteUpdateMessage.new(params.merge(options: { loadbalancing: 'hash', hash_header: 'X-User-ID', hash_balance: -1.0 }))
          expect(message).not_to be_valid
          expect(message.errors.full_messages[0]).to include('Options Hash balance must be greater than or equal to 0.0')
        end

        it 'does not accept unknown load-balancing algorithm' do
          message = RouteUpdateMessage.new(params.merge(options: { loadbalancing: 'cheesecake' }))
          expect(message).not_to be_valid
          expect(message.errors.full_messages[0]).to include("Options Loadbalancing must be one of 'round-robin, least-connection, hash' if present")
        end
      end

      it 'does not accept unknown load-balancing algorithm when feature flag is disabled' do
        message = RouteUpdateMessage.new(params.merge(options: { loadbalancing: 'cheesecake' }))
        expect(message).not_to be_valid
        expect(message.errors.full_messages[0]).to include("Options Loadbalancing must be one of 'round-robin, least-connection' if present")
      end

      it 'does not accept unknown option' do
        message = RouteUpdateMessage.new(params.merge(options: { gorgonzola: 'gouda' }))
        expect(message).not_to be_valid
        expect(message.errors.full_messages[0]).to include("Options Unknown field(s): 'gorgonzola'")
      end
    end

    context 'partial updates with pre-merged options' do
      let(:params) do
        {
          metadata: {
            labels: { potato: 'yam' },
            annotations: { style: 'mashed' }
          }
        }
      end

      before do
        VCAP::CloudController::FeatureFlag.make(name: 'hash_based_routing', enabled: true)
      end

      it 'allows updating hash_balance when all required fields are present' do
        # Controller would merge: existing {loadbalancing: hash, hash_header: X-User-ID, hash_balance: 1.5} + incoming {hash_balance: 2.0}
        message = RouteUpdateMessage.new(params.merge(options: { loadbalancing: 'hash', hash_header: 'X-User-ID', hash_balance: 2.0 }))
        expect(message).to be_valid
      end

      it 'allows updating hash_header when all required fields are present' do
        # Controller would merge: existing {loadbalancing: hash, hash_header: X-User-ID, hash_balance: 1.5} + incoming {hash_header: X-Session-ID}
        message = RouteUpdateMessage.new(params.merge(options: { loadbalancing: 'hash', hash_header: 'X-Session-ID', hash_balance: 1.5 }))
        expect(message).to be_valid
      end

      it 'allows updating both hash_header and hash_balance' do
        message = RouteUpdateMessage.new(params.merge(options: { loadbalancing: 'hash', hash_header: 'X-Request-ID', hash_balance: 2.5 }))
        expect(message).to be_valid
      end

      it 'does not allow hash_header without hash loadbalancing' do
        message = RouteUpdateMessage.new(params.merge(options: { loadbalancing: 'round-robin', hash_header: 'X-User-ID' }))
        expect(message).not_to be_valid
        expect(message.errors.full_messages[0]).to include('Options Hash header can only be set when loadbalancing is hash')
      end

      it 'allows changing from hash to round-robin (action will clean up hash options)' do
        message = RouteUpdateMessage.new(params.merge(options: { loadbalancing: 'round-robin' }))
        expect(message).to be_valid
      end

      it 'requires hash_header when loadbalancing is hash' do
        message = RouteUpdateMessage.new(params.merge(options: { loadbalancing: 'hash' }))
        expect(message).not_to be_valid
        expect(message.errors.full_messages[0]).to include('Options Hash header must be present when loadbalancing is set to hash')
      end
    end
  end
end
