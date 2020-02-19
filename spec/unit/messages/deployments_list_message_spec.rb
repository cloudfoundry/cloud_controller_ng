require 'spec_helper'
require 'messages/deployments_list_message'

module VCAP::CloudController
  RSpec.describe DeploymentsListMessage do
    describe '.from_params' do
      let(:params) do
        {
          'page'      => 1,
          'per_page'  => 5,
          'order_by'  => 'created_at',
          'app_guids' => 'appguid1,appguid2',
          'states' => 'DEPLOYED,CANCELED',
          'status_values' => 'red,green',
          'status_reasons' => '',
          'label_selector' => 'key=value'
        }
      end

      it 'returns the correct DeploymentsListMessage' do
        message = DeploymentsListMessage.from_params(params)

        expect(message).to be_a(DeploymentsListMessage)
        expect(message.page).to eq(1)
        expect(message.per_page).to eq(5)
        expect(message.app_guids).to match_array(['appguid1', 'appguid2'])
        expect(message.states).to match_array(['CANCELED', 'DEPLOYED'])
        expect(message.status_values).to match_array(['red', 'green'])
        expect(message.status_reasons).to match_array([''])
        expect(message.order_by).to eq('created_at')
        expect(message.label_selector).to eq('key=value')
        expect(message).to be_valid
      end

      it 'converts requested keys to symbols' do
        message = DeploymentsListMessage.from_params(params)

        expect(message.requested?(:page)).to be true
        expect(message.requested?(:per_page)).to be true
        expect(message.requested?(:app_guids)).to be true
        expect(message.requested?(:order_by)).to be true
        expect(message.requested?(:states)).to be true
        expect(message.requested?(:status_values)).to be true
        expect(message.requested?(:status_reasons)).to be true
        expect(message.requested?(:label_selector)).to be true
      end
    end

    describe 'validations' do
      it 'accepts a set of params' do
        message = DeploymentsListMessage.from_params({
          app_guids: [],
          page:      1,
          per_page:  5,
          order_by:  'created_at',
          states: [],
          status_values: [],
          status_reasons: [],
        })
        expect(message).to be_valid
      end

      it 'accepts an empty set' do
        message = DeploymentsListMessage.from_params({})
        expect(message).to be_valid
      end

      it 'does not accept a param not in this set' do
        message = DeploymentsListMessage.from_params({ foobar: 'pants' })

        expect(message).not_to be_valid
        expect(message.errors[:base][0]).to include("Unknown query parameter(s): 'foobar'")
      end

      it 'reject an invalid order_by param' do
        message = DeploymentsListMessage.from_params({
          order_by:  'fail!',
        })
        expect(message).not_to be_valid
      end

      it 'validates app_guids is an array' do
        message = DeploymentsListMessage.from_params app_guids: 'tricked you, not an array'
        expect(message).to be_invalid
        expect(message.errors[:app_guids].length).to eq 1
      end

      it 'validates states is an array' do
        message = DeploymentsListMessage.from_params states: 'tricked you, not an array'
        expect(message).to be_invalid
        expect(message.errors[:states].length).to eq 1
      end

      it 'validates status_reasons is an array' do
        message = DeploymentsListMessage.from_params status_reasons: 'tricked you, not an array'
        expect(message).to be_invalid
        expect(message.errors[:status_reasons].length).to eq 1
      end

      it 'validates status_values is an array' do
        message = DeploymentsListMessage.from_params status_values: 'tricked you, not an array'
        expect(message).to be_invalid
        expect(message.errors[:status_values].length).to eq 1
      end

      it 'validates label selector' do
        message = DeploymentsListMessage.from_params('label_selector' => '')

        expect_any_instance_of(Validators::LabelSelectorRequirementValidator).
          to receive(:validate).
          with(message).
          and_call_original
        message.valid?
      end
    end
  end
end
