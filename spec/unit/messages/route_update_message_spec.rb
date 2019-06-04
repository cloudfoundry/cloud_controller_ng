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

      it 'does not accept any other params' do
        message = RouteUpdateMessage.new(params.merge(unexpected: 'unexpected_value'))
        expect(message).not_to be_valid
        expect(message.errors.full_messages[0]).to include("Unknown field(s): 'unexpected'")
      end
    end
  end
end
