require 'spec_helper'
require 'messages/packages_list_message'

module VCAP::CloudController
  RSpec.describe PackagesListMessage do
    describe '.from_params' do
      let(:params) do
        {
          'states' => 'state1,state2',
          'types' => 'type1,type2',
          'app_guids' => 'appguid1,appguid2',
          'space_guids' => 'spaceguid1,spaceguid2',
          'organization_guids' => 'organizationguid1,organizationguid2',
          'guids' => 'guid1,guid2',
          'page' => 1,
          'per_page' => 5,
          'label_selector' => 'key=value'
        }
      end

      it 'returns the correct PackagesListMessage' do
        message = PackagesListMessage.from_params(params)

        expect(message).to be_a(PackagesListMessage)
        expect(message.page).to eq(1)
        expect(message.per_page).to eq(5)
        expect(message.states).to eq(%w[state1 state2])
        expect(message.types).to eq(%w[type1 type2])
        expect(message.app_guids).to eq(%w[appguid1 appguid2])
        expect(message.guids).to eq(%w[guid1 guid2])
        expect(message.space_guids).to eq(%w[spaceguid1 spaceguid2])
        expect(message.organization_guids).to eq(%w[organizationguid1 organizationguid2])
        expect(message.label_selector).to eq('key=value')
      end

      it 'converts requested keys to symbols' do
        message = PackagesListMessage.from_params(params)

        expect(message).to be_requested(:page)
        expect(message).to be_requested(:per_page)
        expect(message).to be_requested(:states)
        expect(message).to be_requested(:types)
        expect(message).to be_requested(:app_guids)
        expect(message).to be_requested(:space_guids)
        expect(message).to be_requested(:organization_guids)
        expect(message).to be_requested(:label_selector)
      end
    end

    describe '#to_param_hash' do
      let(:opts) do
        {
          types: %w[bits docker],
          states: %w[SUCCEEDED FAILED],
          guids: %w[guid1 guid2],
          space_guids: %w[spaceguid1 spaceguid2],
          app_guids: %w[appguid1 appguid2],
          organization_guids: %w[organizationguid1 organizationguid2],
          app_guid: 'appguid',
          label_selector: 'key=value',
          page: 1,
          per_page: 5
        }
      end

      it 'excludes the pagination keys' do
        expected_params = %i[states types app_guids guids space_guids organization_guids label_selector]
        expect(PackagesListMessage.from_params(opts).to_param_hash.keys).to match_array(expected_params)
      end
    end

    describe 'fields' do
      it 'accepts a set of fields' do
        expect do
          PackagesListMessage.from_params({
                                            page: 1,
                                            per_page: 5,
                                            states: ['READY'],
                                            types: ['bits'],
                                            guids: ['package-guid'],
                                            app_guids: ['app-guid'],
                                            space_guids: ['space-guid'],
                                            organization_guids: ['organization-guid']
                                          })
        end.not_to raise_error
      end

      it 'accepts an empty set' do
        message = PackagesListMessage.from_params({})
        expect(message).to be_valid
      end

      it 'does not accept a field not in this set' do
        message = PackagesListMessage.from_params({ foobar: 'pants' })

        expect(message).not_to be_valid
        expect(message.errors[:base][0]).to include("Unknown query parameter(s): 'foobar'")
      end
    end

    describe 'validations' do
      context 'types' do
        it 'validates types to be an array' do
          message = PackagesListMessage.from_params(types: 'not array at all')
          expect(message).not_to be_valid
          expect(message.errors[:types]).to include('must be an array')
        end

        it 'allows types to be nil' do
          message = PackagesListMessage.from_params(types: nil)
          expect(message).to be_valid
        end
      end

      context 'states' do
        it 'validates states to be an array' do
          message = PackagesListMessage.from_params(states: 'not array at all')
          expect(message).not_to be_valid
          expect(message.errors[:states]).to include('must be an array')
        end

        it 'allows states to be nil' do
          message = PackagesListMessage.from_params(states: nil)
          expect(message).to be_valid
        end
      end

      context 'app guids' do
        it 'validates app_guids is an array' do
          message = PackagesListMessage.from_params app_guids: 'tricked you, not an array'
          expect(message).not_to be_valid
          expect(message.errors[:app_guids]).to include('must be an array')
        end

        context 'app nested requests' do
          context 'user provides app_guids' do
            it 'is not valid' do
              message = PackagesListMessage.from_params({ app_guid: 'blah', app_guids: %w[app1 app2] })
              expect(message).not_to be_valid
              expect(message.errors[:base][0]).to include("Unknown query parameter(s): 'app_guids'")
            end
          end

          context 'user provides organization_guids' do
            it 'is not valid' do
              message = PackagesListMessage.from_params({ app_guid: 'blah', organization_guids: %w[orgguid1 orgguid2] })
              expect(message).not_to be_valid
              expect(message.errors[:base][0]).to include("Unknown query parameter(s): 'organization_guids'")
            end
          end

          context 'user provides space guids' do
            it 'is not valid' do
              message = PackagesListMessage.from_params({ app_guid: 'blah', space_guids: %w[space1 space2] })
              expect(message).not_to be_valid
              expect(message.errors[:base][0]).to include("Unknown query parameter(s): 'space_guids'")
            end
          end
        end
      end

      context 'guids' do
        it 'is not valid if guids is not an array' do
          message = PackagesListMessage.from_params guids: 'tricked you, not an array'
          expect(message).not_to be_valid
          expect(message.errors[:guids]).to include('must be an array')
        end

        it 'allows guids to be nil' do
          message = PackagesListMessage.from_params(guids: nil)
          expect(message).to be_valid
        end
      end

      context 'space_guids' do
        it 'validates space_guids to be an array' do
          message = PackagesListMessage.from_params(space_guids: 'not an array at all')
          expect(message).not_to be_valid
          expect(message.errors[:space_guids]).to include('must be an array')
        end

        it 'allows space_guids to be nil' do
          message = PackagesListMessage.from_params(space_guids: nil)
          expect(message).to be_valid
        end
      end

      context 'organization_guids' do
        it 'validates organization_guids to be an array' do
          message = PackagesListMessage.from_params(organization_guids: 'not an array at all')
          expect(message).not_to be_valid
          expect(message.errors[:organization_guids]).to include('must be an array')
        end

        it 'allows organization_guids to be nil' do
          message = PackagesListMessage.from_params(organization_guids: nil)
          expect(message).to be_valid
        end
      end

      it 'validates metadata requirements' do
        message = PackagesListMessage.from_params('label_selector' => '')

        expect_any_instance_of(Validators::LabelSelectorRequirementValidator).
          to receive(:validate).
          with(message).
          and_call_original
        message.valid?
      end
    end
  end
end
