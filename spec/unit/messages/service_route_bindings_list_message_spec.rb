require 'spec_helper'
require 'messages/service_route_bindings_list_message'

module VCAP
  module CloudController
    RSpec.describe ServiceRouteBindingsListMessage do
      describe '.from_params' do
        let(:params) do
          {
            'page'      => 1,
            'per_page'  => 5,
            'service_instance_guids' => 'guid-1,guid-2,guid-3',
            'service_instance_names' => 'name-1,name-2,name-3',
            'route_guids' => 'guid-4,guid-5,guid-6',
            'include' => 'service_instance'
          }
        end

        let(:message) { ServiceRouteBindingsListMessage.from_params(params) }

        it 'returns the correct ServiceBrokersListMessage' do
          expect(message).to be_a(ServiceRouteBindingsListMessage)

          expect(message.page).to eq(1)
          expect(message.per_page).to eq(5)
          expect(message.service_instance_guids).to eq(%w[guid-1 guid-2 guid-3])
          expect(message.service_instance_names).to eq(%w[name-1 name-2 name-3])
          expect(message.route_guids).to eq(%w[guid-4 guid-5 guid-6])
          expect(message.include).to eq(%w[service_instance])
        end

        it 'converts requested keys to symbols' do
          expect(message.requested?(:page)).to be_truthy
          expect(message.requested?(:per_page)).to be_truthy
          expect(message.requested?(:service_instance_guids)).to be_truthy
          expect(message.requested?(:service_instance_names)).to be_truthy
          expect(message.requested?(:route_guids)).to be_truthy
        end
      end
    end
  end
end
