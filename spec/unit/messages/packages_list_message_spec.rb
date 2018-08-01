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
          'page'     => 1,
          'per_page' => 5,
        }
      end

      it 'returns the correct PackagesListMessage' do
        message = PackagesListMessage.from_params(params)

        expect(message).to be_a(PackagesListMessage)
        expect(message.page).to eq(1)
        expect(message.per_page).to eq(5)
        expect(message.states).to eq(['state1', 'state2'])
        expect(message.types).to eq(['type1', 'type2'])
        expect(message.app_guids).to eq(['appguid1', 'appguid2'])
        expect(message.guids).to eq(['guid1', 'guid2'])
        expect(message.space_guids).to eq(['spaceguid1', 'spaceguid2'])
        expect(message.organization_guids).to eq(['organizationguid1', 'organizationguid2'])
      end

      it 'converts requested keys to symbols' do
        message = PackagesListMessage.from_params(params)

        expect(message.requested?(:page)).to be_truthy
        expect(message.requested?(:per_page)).to be_truthy
        expect(message.requested?(:states)).to be_truthy
        expect(message.requested?(:types)).to be_truthy
        expect(message.requested?(:app_guids)).to be_truthy
        expect(message.requested?(:space_guids)).to be_truthy
        expect(message.requested?(:organization_guids)).to be_truthy
      end
    end

    describe '#to_param_hash' do
      let(:opts) do
        {
          types:              ['bits', 'docker'],
          states:             ['SUCCEEDED', 'FAILED'],
          guids:              ['guid1', 'guid2'],
          space_guids:        ['spaceguid1', 'spaceguid2'],
          app_guids:          ['appguid1', 'appguid2'],
          organization_guids: ['organizationguid1', 'organizationguid2'],
          app_guid:           'appguid',
          page:               1,
          per_page:           5,
        }
      end

      it 'excludes the pagination keys' do
        expected_params = [:states, :types, :app_guids, :guids, :space_guids, :organization_guids]
        expect(PackagesListMessage.new(opts).to_param_hash.keys).to match_array(expected_params)
      end
    end

    describe 'fields' do
      it 'accepts a set of fields' do
        expect {
          PackagesListMessage.new({
              page:               1,
              per_page:           5,
              states:             ['READY'],
              types:              ['bits'],
              guids:              ['package-guid'],
              app_guids:          ['app-guid'],
              space_guids:        ['space-guid'],
              organization_guids: ['organization-guid'],
            })
        }.not_to raise_error
      end

      it 'accepts an empty set' do
        message = PackagesListMessage.new
        expect(message).to be_valid
      end

      it 'does not accept a field not in this set' do
        message = PackagesListMessage.new({ foobar: 'pants' })

        expect(message).not_to be_valid
        expect(message.errors[:base]).to include("Unknown query parameter(s): 'foobar'")
      end
    end

    describe 'validations' do
      context 'types' do
        it 'validates types to be an array' do
          message = PackagesListMessage.new(types: 'not array at all')
          expect(message).to be_invalid
          expect(message.errors[:types]).to include('must be an array')
        end

        it 'allows types to be nil' do
          message = PackagesListMessage.new(types: nil)
          expect(message).to be_valid
        end
      end

      context 'states' do
        it 'validates states to be an array' do
          message = PackagesListMessage.new(states: 'not array at all')
          expect(message).to be_invalid
          expect(message.errors[:states]).to include('must be an array')
        end

        it 'allows states to be nil' do
          message = PackagesListMessage.new(states: nil)
          expect(message).to be_valid
        end
      end

      context 'app guids' do
        it 'validates app_guids is an array' do
          message = PackagesListMessage.new app_guids: 'tricked you, not an array'
          expect(message).to be_invalid
          expect(message.errors[:app_guids]).to include('must be an array')
        end

        context 'app nested requests' do
          context 'user provides app_guids' do
            it 'is not valid' do
              message = PackagesListMessage.new({ app_guid: 'blah', app_guids: ['app1', 'app2'] })
              expect(message).to_not be_valid
              expect(message.errors[:base]).to include("Unknown query parameter(s): 'app_guids'")
            end
          end

          context 'user provides organization_guids' do
            it 'is not valid' do
              message = PackagesListMessage.new({ app_guid: 'blah', organization_guids: ['orgguid1', 'orgguid2'] })
              expect(message).to_not be_valid
              expect(message.errors[:base]).to include("Unknown query parameter(s): 'organization_guids'")
            end
          end

          context 'user provides space guids' do
            it 'is not valid' do
              message = PackagesListMessage.new({ app_guid: 'blah', space_guids: ['space1', 'space2'] })
              expect(message).to_not be_valid
              expect(message.errors[:base]).to include("Unknown query parameter(s): 'space_guids'")
            end
          end
        end
      end

      context 'guids' do
        it 'is not valid if guids is not an array' do
          message = PackagesListMessage.new guids: 'tricked you, not an array'
          expect(message).to be_invalid
          expect(message.errors[:guids]). to include('must be an array')
        end

        it 'allows guids to be nil' do
          message = PackagesListMessage.new(guids: nil)
          expect(message).to be_valid
        end
      end

      context 'space_guids' do
        it 'validates space_guids to be an array' do
          message = PackagesListMessage.new(space_guids: 'not an array at all')
          expect(message).to be_invalid
          expect(message.errors[:space_guids]).to include('must be an array')
        end

        it 'allows space_guids to be nil' do
          message = PackagesListMessage.new(space_guids: nil)
          expect(message).to be_valid
        end
      end

      context 'organization_guids' do
        it 'validates organization_guids to be an array' do
          message = PackagesListMessage.new(organization_guids: 'not an array at all')
          expect(message).to be_invalid
          expect(message.errors[:organization_guids]).to include('must be an array')
        end

        it 'allows organization_guids to be nil' do
          message = PackagesListMessage.new(organization_guids: nil)
          expect(message).to be_valid
        end
      end
    end
  end
end
