require 'lightweight_spec_helper'
require 'messages/service_route_binding_show_message'

module VCAP
  module CloudController
    RSpec.describe ServiceRouteBindingShowMessage do
      describe '.from_params' do
        let(:params) do
          {
            'include' => 'service_instance'
          }
        end

        let(:message) { ServiceRouteBindingShowMessage.from_params(params) }

        it 'returns the correct ServiceBrokersListMessage' do
          expect(message).to be_a(ServiceRouteBindingShowMessage)

          expect(message.include).to eq(%w[service_instance])
        end
      end

      describe 'validations' do
        context 'include' do
          it 'returns false for arbitrary values' do
            message = described_class.from_params({ 'include' => 'app' })
            expect(message).not_to be_valid
            expect(message.errors[:base]).to include(include("Invalid included resource: 'app'"))
          end

          it 'returns true for valid values' do
            message = described_class.from_params({ 'include' => 'route, service_instance' })
            expect(message).to be_valid
          end
        end
      end
    end
  end
end
