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

      it 'accepts options params with least-connections load-balancing algorithm' do
        message = RouteUpdateMessage.new(params.merge(options: { loadbalancing: 'least-connections' }))
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
        expect(message.errors.full_messages[0]).to include("Options Loadbalancing 'cheesecake' is not supported")
      end

      it 'does not accept unknown option' do
        message = RouteUpdateMessage.new(params.merge(options: { gorgonzola: 'gouda' }))
        expect(message).not_to be_valid
        expect(message.errors.full_messages[0]).to include("Options Unknown field(s): 'gorgonzola'")
      end
    end
  end
end
