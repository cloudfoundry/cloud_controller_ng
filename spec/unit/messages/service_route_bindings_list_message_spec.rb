require 'lightweight_spec_helper'
require 'messages/service_route_bindings_list_message'

module VCAP
  module CloudController
    RSpec.describe ServiceRouteBindingsListMessage do
      let(:params) do
        {
          'page'      => 1,
          'per_page'  => 5,
          'service_instance_guids' => 'guid-1,guid-2,guid-3',
          'service_instance_names' => 'name-1,name-2,name-3',
          'route_guids' => 'guid-4,guid-5,guid-6',
          'label_selector' => 'key=value',
          'include' => 'service_instance'
        }
      end

      describe '.from_params' do
        let(:message) { ServiceRouteBindingsListMessage.from_params(params) }

        it 'returns the correct ServiceBrokersListMessage' do
          expect(message).to be_a(ServiceRouteBindingsListMessage)

          expect(message.page).to eq(1)
          expect(message.per_page).to eq(5)
          expect(message.service_instance_guids).to eq(%w[guid-1 guid-2 guid-3])
          expect(message.service_instance_names).to eq(%w[name-1 name-2 name-3])
          expect(message.route_guids).to eq(%w[guid-4 guid-5 guid-6])
          expect(message.include).to eq(%w[service_instance])
          expect(message.label_selector).to eq('key=value')
        end

        it 'converts requested keys to symbols' do
          expect(message.requested?(:page)).to be_truthy
          expect(message.requested?(:per_page)).to be_truthy
          expect(message.requested?(:service_instance_guids)).to be_truthy
          expect(message.requested?(:service_instance_names)).to be_truthy
          expect(message.requested?(:route_guids)).to be_truthy
          expect(message.requested?(:label_selector)).to be_truthy
        end
      end

      describe '#valid?' do
        it 'returns true for valid fields' do
          message = described_class.from_params(params)
          expect(message).to be_valid
        end

        it 'returns true for empty fields' do
          message = described_class.from_params({})
          expect(message).to be_valid
        end

        it 'returns false for invalid fields' do
          message = described_class.from_params({ 'foobar' => 'pants' })
          expect(message).not_to be_valid
          expect(message.errors[:base][0]).to include("Unknown query parameter(s): 'foobar'")
        end

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

        it 'validates metadata requirements' do
          message = described_class.from_params({ 'label_selector' => '' }.with_indifferent_access)

          expect_any_instance_of(Validators::LabelSelectorRequirementValidator).
            to receive(:validate).
            with(message).
            and_call_original
          message.valid?
        end
      end
    end
  end
end
