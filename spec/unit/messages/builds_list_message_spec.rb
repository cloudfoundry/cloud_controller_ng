require 'spec_helper'
require 'messages/builds_list_message'

module VCAP::CloudController
  RSpec.describe BuildsListMessage do
    describe '.from_params' do
      let(:params) do
        {
          'states'    => 'state1,state2',
          'app_guids' => 'appguid1,appguid2',
          'package_guids' => 'packageguid1,packageguid2',
          'page'      => 1,
          'per_page'  => 5,
          'order_by'  => 'created_at',
          'label_selector' => 'key=value',
          'created_ats'        => "#{Time.now.utc.iso8601},#{Time.now.utc.iso8601}",
          'updated_ats'        => { gt: Time.now.utc.iso8601 }
        }
      end

      it 'returns the correct BuildsListMessage' do
        message = BuildsListMessage.from_params(params)

        expect(message).to be_a(BuildsListMessage)
        expect(message.states).to eq(['state1', 'state2'])
        expect(message.app_guids).to eq(['appguid1', 'appguid2'])
        expect(message.package_guids).to eq(['packageguid1', 'packageguid2'])
        expect(message.page).to eq(1)
        expect(message.per_page).to eq(5)
        expect(message.order_by).to eq('created_at')
        expect(message.label_selector).to eq('key=value')
      end

      it 'converts requested keys to symbols' do
        message = BuildsListMessage.from_params(params)

        expect(message.requested?(:states)).to be true
        expect(message.requested?(:app_guids)).to be true
        expect(message.requested?(:package_guids)).to be true
        expect(message.requested?(:page)).to be true
        expect(message.requested?(:per_page)).to be true
        expect(message.requested?(:order_by)).to be true
        expect(message.requested?(:created_ats)).to be_truthy
        expect(message.requested?(:updated_ats)).to be_truthy
      end
    end

    describe 'fields' do
      it 'accepts a set of fields' do
        message = BuildsListMessage.from_params({
          app_guids: [],
          package_guids: [],
          states:    [],
          page:      1,
          per_page:  5,
          order_by:  'created_at',
        })
        expect(message).to be_valid
      end

      it 'accepts an empty set' do
        message = BuildsListMessage.from_params({})
        expect(message).to be_valid
      end

      it 'does not accept a field not in this set' do
        message = BuildsListMessage.from_params({ foobar: 'pants' })

        expect(message).not_to be_valid
        expect(message.errors[:base][0]).to include("Unknown query parameter(s): 'foobar'")
      end

      it 'reject an invalid order_by field' do
        message = BuildsListMessage.from_params({
          order_by:  'fail!',
        })
        expect(message).not_to be_valid
      end

      describe 'validations' do
        context 'when the request contains space_guids' do
          it 'is invalid' do
            message = BuildsListMessage.from_params({ app_guids: ['blah'], space_guids: ['app1', 'app2'] })
            expect(message).to_not be_valid
            expect(message.errors[:base][0]).to include("Unknown query parameter(s): 'space_guids'")
          end
        end

        context 'when the request contains organization_guids' do
          it 'is invalid' do
            message = BuildsListMessage.from_params({ app_guids: ['blah'], organization_guids: ['app1', 'app2'] })
            expect(message).to_not be_valid
            expect(message.errors[:base][0]).to include("Unknown query parameter(s): 'organization_guids'")
          end
        end

        it 'validates app_guids is an array' do
          message = BuildsListMessage.from_params app_guids: 'tricked you, not an array'
          expect(message).to be_invalid
          expect(message.errors[:app_guids].length).to eq 1
        end

        it 'validates package_guids is an array' do
          message = BuildsListMessage.from_params package_guids: 'also not an array'
          expect(message).to be_invalid
          expect(message.errors[:package_guids].length).to eq 1
        end

        it 'validates states is an array' do
          message = BuildsListMessage.from_params states: 'not array at all'
          expect(message).to be_invalid
          expect(message.errors[:states].length).to eq 1
        end

        it 'validates metadata requirements' do
          message = BuildsListMessage.from_params('label_selector' => '')

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
