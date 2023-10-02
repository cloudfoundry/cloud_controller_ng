require 'spec_helper'
require 'messages/droplets_list_message'

module VCAP::CloudController
  RSpec.describe DropletsListMessage do
    describe '.from_params' do
      let(:params) do
        {
          'app_guid' => 'app-guid',
          'package_guid' => 'package-guid',
          'states' => 'state1,state2',
          'app_guids' => 'appguid1,appguid2',
          'page' => 1,
          'per_page' => 5,
          'order_by' => 'created_at',
          'guids' => 'guid1,guid2',
          'space_guids' => 'guid3,guid4',
          'organization_guids' => 'guid3,guid4',
          'current' => true
        }
      end

      it 'returns the correct DropletsListMessage' do
        message = DropletsListMessage.from_params(params)

        expect(message).to be_a(DropletsListMessage)
        expect(message.app_guid).to eq('app-guid')
        expect(message.package_guid).to eq('package-guid')
        expect(message.states).to eq(%w[state1 state2])
        expect(message.app_guids).to eq(%w[appguid1 appguid2])
        expect(message.page).to eq(1)
        expect(message.per_page).to eq(5)
        expect(message.order_by).to eq('created_at')
        expect(message.guids).to match_array(%w[guid1 guid2])
        expect(message.space_guids).to match_array(%w[guid3 guid4])
        expect(message.organization_guids).to match_array(%w[guid3 guid4])
        expect(message.current).to be(true)
      end

      it 'converts requested keys to symbols' do
        message = DropletsListMessage.from_params(params)

        expect(message.requested?(:app_guid)).to be true
        expect(message.requested?(:package_guid)).to be true
        expect(message.requested?(:states)).to be true
        expect(message.requested?(:app_guids)).to be true
        expect(message.requested?(:page)).to be true
        expect(message.requested?(:per_page)).to be true
        expect(message.requested?(:order_by)).to be true
        expect(message.requested?(:space_guids)).to be true
        expect(message.requested?(:organization_guids)).to be true
        expect(message.requested?(:current)).to be true
      end
    end

    describe 'fields' do
      it 'accepts a set of fields' do
        message = DropletsListMessage.from_params({
                                                    app_guids: [],
                                                    states: [],
                                                    page: 1,
                                                    per_page: 5,
                                                    order_by: 'created_at',
                                                    guids: %w[guid1 guid2],
                                                    space_guids: %w[guid3 guid4],
                                                    organization_guids: %w[guid3 guid4]
                                                  })
        expect(message).to be_valid
      end

      it 'accepts an empty set' do
        message = DropletsListMessage.from_params({})
        expect(message).to be_valid
      end

      it 'does not accept a field not in this set' do
        message = DropletsListMessage.from_params({ foobar: 'pants' })

        expect(message).not_to be_valid
        expect(message.errors[:base][0]).to include("Unknown query parameter(s): 'foobar'")
      end

      describe 'validations' do
        context 'when the query is nested under an app' do
          context 'when the app_guid is present' do
            context 'when the request contains organization_guids' do
              it 'is invalid' do
                message = DropletsListMessage.from_params({ app_guid: 'blah', organization_guids: %w[app1 app2] })
                expect(message).not_to be_valid
                expect(message.errors[:base][0]).to include("Unknown query parameter(s): 'organization_guids'")
              end
            end

            context 'when the request contains space_guids' do
              it 'is invalid' do
                message = DropletsListMessage.from_params({ app_guid: 'blah', space_guids: %w[app1 app2] })
                expect(message).not_to be_valid
                expect(message.errors[:base][0]).to include("Unknown query parameter(s): 'space_guids'")
              end
            end

            context 'when the request contains app_guids' do
              it 'is invalid' do
                message = DropletsListMessage.from_params({ app_guid: 'blah', app_guids: %w[app1 app2] })
                expect(message).not_to be_valid
                expect(message.errors[:base][0]).to include("Unknown query parameter(s): 'app_guids'")
              end
            end

            context 'when the request contains the current field' do
              it 'is valid' do
                message = DropletsListMessage.from_params({ app_guid: 'blah', current: 'true' })
                expect(message).to be_valid
              end

              it 'validates current must be true' do
                message = DropletsListMessage.from_params({ app_guid: 'blah', current: 'false' })
                expect(message).not_to be_valid
                expect(message.errors[:current].length).to eq(1)
                expect(message.errors[:current]).to include("only accepts the value 'true'")
              end
            end
          end
        end

        context 'when the query is not nested under an app' do
          context 'when the request contains current field' do
            it 'is invalid' do
              message = DropletsListMessage.from_params({ current: 'true' })
              expect(message).not_to be_valid
              expect(message.errors[:base][0]).to include("Unknown query parameter(s): 'current'")
            end
          end
        end

        it 'validates organization_guids is an array' do
          message = DropletsListMessage.from_params organization_guids: 'tricked you, not an array'
          expect(message).not_to be_valid
          expect(message.errors[:organization_guids].length).to eq 1
        end

        it 'validates space_guids is an array' do
          message = DropletsListMessage.from_params space_guids: 'tricked you, not an array'
          expect(message).not_to be_valid
          expect(message.errors[:space_guids].length).to eq 1
        end

        it 'validates app_guids is an array' do
          message = DropletsListMessage.from_params app_guids: 'tricked you, not an array'
          expect(message).not_to be_valid
          expect(message.errors[:app_guids].length).to eq 1
        end

        it 'validates states is an array' do
          message = DropletsListMessage.from_params states: 'not array at all'
          expect(message).not_to be_valid
          expect(message.errors[:states].length).to eq 1
        end
      end
    end

    describe '#to_param_hash' do
      it 'excludes app_guid' do
        expect(DropletsListMessage.from_params({ app_guid: '24234' }).to_param_hash.keys).to be_empty
      end

      it 'excludes package_guid' do
        expect(DropletsListMessage.from_params({ package_guid: '24234' }).to_param_hash.keys).to be_empty
      end
    end

    describe 'validations' do
      it 'validates label_selector' do
        message = SpacesListMessage.from_params('label_selector' => '')

        expect_any_instance_of(Validators::LabelSelectorRequirementValidator).to receive(:validate).with(message).and_call_original
        message.valid?
      end
    end
  end
end
