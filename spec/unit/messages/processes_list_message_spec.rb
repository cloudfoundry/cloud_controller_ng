require 'spec_helper'
require 'messages/processes_list_message'

module VCAP::CloudController
  describe ProcessesListMessage do
    describe '.from_params' do
      let(:params) do
        {
          'page'     => 1,
          'per_page' => 5,
          'app_guid' => 'some-app-guid',
          'types' => 'web',
          'space_guids' => 'the_space_guid',
          'organization_guids' => 'the_organization_guid',
          'app_guids' => 'the-app-guid'
        }
      end

      it 'returns the correct ProcessesListMessage' do
        message = ProcessesListMessage.from_params(params)

        expect(message).to be_a(ProcessesListMessage)
        expect(message.page).to eq(1)
        expect(message.per_page).to eq(5)
        expect(message.app_guid).to eq('some-app-guid')
        expect(message.types).to eq(['web'])
        expect(message.space_guids).to eq(['the_space_guid'])
        expect(message.organization_guids).to eq(['the_organization_guid'])
        expect(message.app_guids).to eq(['the-app-guid'])
      end

      it 'converts requested keys to symbols' do
        message = ProcessesListMessage.from_params(params)

        expect(message.requested?(:page)).to be_truthy
        expect(message.requested?(:per_page)).to be_truthy
        expect(message.requested?(:app_guid)).to be_truthy
        expect(message.requested?(:types)).to be_truthy
        expect(message.requested?(:space_guids)).to be_truthy
        expect(message.requested?(:organization_guids)).to be_truthy
        expect(message.requested?(:app_guids)).to be_truthy
      end
    end

    describe '#to_param_hash' do
      let(:opts) do
        {
          types:              ['bits', 'docker'],
          space_guids:        ['spaceguid1', 'spaceguid2'],
          app_guids:          ['appguid1', 'appguid2'],
          organization_guids: ['organizationguid1', 'organizationguid2'],
          app_guid:           'appguid',
          page:               1,
          per_page:           5,
        }
      end

      it 'excludes the pagination keys' do
        expected_params = [:types, :app_guids, :space_guids, :organization_guids]
        message = ProcessesListMessage.new(opts)

        expect(message.to_param_hash.keys).to match_array(expected_params)
      end
    end

    describe 'fields' do
      it 'accepts a set of fields' do
        expect {
          ProcessesListMessage.new({
            types:              ['bits', 'docker'],
            space_guids:        ['spaceguid1', 'spaceguid2'],
            app_guids:          ['appguid1', 'appguid2'],
            organization_guids: ['organizationguid1', 'organizationguid2'],
            app_guid:           'appguid',
            page:               1,
            per_page:           5
          })
        }.not_to raise_error
      end

      it 'accepts an empty set' do
        message = ProcessesListMessage.new
        expect(message).to be_valid
      end

      it 'does not accept a field not in this set' do
        message = ProcessesListMessage.new({ foobar: 'pants' })

        expect(message).not_to be_valid
        expect(message.errors[:base]).to include("Unknown query parameter(s): 'foobar'")
      end
    end

    describe 'validations' do
      context 'types' do
        it 'validates types to be an array' do
          message = ProcessesListMessage.new(types: 'not array at all')
          expect(message).to be_invalid
          expect(message.errors[:types]).to include('must be an array')
        end

        it 'allows types to be nil' do
          message = ProcessesListMessage.new(types: nil)
          expect(message).to be_valid
        end
      end

      context 'app guids' do
        it 'validates app_guids is an array' do
          message = ProcessesListMessage.new app_guids: 'tricked you, not an array'
          expect(message).to be_invalid
          expect(message.errors[:app_guids]).to include('must be an array')
        end

        context 'app nested requests' do
          context 'user provides app_guids' do
            it 'is not valid' do
              message = ProcessesListMessage.new({ app_guid: 'blah', app_guids: ['app1', 'app2'] })
              expect(message).to_not be_valid
              expect(message.errors[:base]).to include("Unknown query parameter(s): 'app_guids'")
            end
          end

          context 'user provides organization_guids' do
            it 'is not valid' do
              message = ProcessesListMessage.new({ app_guid: 'blah', organization_guids: ['orgguid1', 'orgguid2'] })
              expect(message).to_not be_valid
              expect(message.errors[:base]).to include("Unknown query parameter(s): 'organization_guids'")
            end
          end

          context 'user provides space guids' do
            it 'is not valid' do
              message = ProcessesListMessage.new({ app_guid: 'blah', space_guids: ['space1', 'space2'] })
              expect(message).to_not be_valid
              expect(message.errors[:base]).to include("Unknown query parameter(s): 'space_guids'")
            end
          end
        end
      end

      context 'space_guids' do
        it 'validates space_guids to be an array' do
          message = ProcessesListMessage.new(space_guids: 'not an array at all')
          expect(message).to be_invalid
          expect(message.errors[:space_guids]).to include('must be an array')
        end

        it 'allows space_guids to be nil' do
          message = ProcessesListMessage.new(space_guids: nil)
          expect(message).to be_valid
        end
      end

      context 'organization_guids' do
        it 'validates organization_guids to be an array' do
          message = ProcessesListMessage.new(organization_guids: 'not an array at all')
          expect(message).to be_invalid
          expect(message.errors[:organization_guids]).to include('must be an array')
        end

        it 'allows organization_guids to be nil' do
          message = ProcessesListMessage.new(organization_guids: nil)
          expect(message).to be_valid
        end
      end
    end
  end
end
