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

      it 'accepts options params with round-robin load-balancing algorithm' do
        message = RouteUpdateMessage.new(params.merge(options: { lb_algo: 'round-robin' }))
        expect(message).to be_valid
      end

      it 'accepts options params with least-connections load-balancing algorithm' do
        message = RouteUpdateMessage.new(params.merge(options: { lb_algo: 'least-connections' }))
        expect(message).to be_valid
      end

      it 'accepts options: nil to unset options' do
        message = RouteUpdateMessage.new(params.merge(options: nil))
        expect(message).to be_valid
      end

      it 'accepts lb_algo: nil to unset load-balancing algorithm' do
        message = RouteUpdateMessage.new(params.merge(options: { lb_algo: nil }))
        expect(message).to be_valid
      end

      it 'does not accept any other params' do
        message = RouteUpdateMessage.new(params.merge(unexpected: 'unexpected_value'))
        expect(message).not_to be_valid
        expect(message.errors.full_messages[0]).to include("Unknown field(s): 'unexpected'")
      end

      it 'does not accept unknown load-balancing algorithm' do
        message = RouteUpdateMessage.new(params.merge(options: { lb_algo: 'cheesecake' }))
        expect(message).not_to be_valid
        expect(message.errors.full_messages[0]).to include("Options Lb algo 'cheesecake' is not a supported load-balancing algorithm")
      end

      it 'does not accept unknown option' do
        message = RouteUpdateMessage.new(params.merge(options: { gorgonzola: 'gouda' }))
        expect(message).not_to be_valid
        expect(message.errors.full_messages[0]).to include("Options Unknown field(s): 'gorgonzola'")
      end
    end
  end
end
