require 'spec_helper'
require 'messages/processes_list_message'

module VCAP::CloudController
  RSpec.describe ProcessesListMessage do
    describe '.from_params' do
      let(:params) do
        {
          'page'     => 1,
          'per_page' => 5,
          'app_guid' => 'some-app-guid',
          'types' => 'web,worker',
          'space_guids' => 'the_space_guid,another-space-guid',
          'organization_guids' => 'the_organization_guid, another-org-guid',
          'app_guids' => 'the-app-guid, the-app-guid2',
          'guids' => 'process-guid,process-guid2',
          'order_by' => 'created_at',
        }
      end

      it 'parses comma-delimited filter keys into arrays' do
        message = ProcessesListMessage.from_params(params)

        expect(message).to be_a(ProcessesListMessage)
        expect(message.page).to eq(1)
        expect(message.per_page).to eq(5)
        expect(message.app_guid).to eq('some-app-guid')
        expect(message.types).to eq(['web', 'worker'])
        expect(message.space_guids).to eq(['the_space_guid', 'another-space-guid'])
        expect(message.organization_guids).to eq(['the_organization_guid', 'another-org-guid'])
        expect(message.app_guids).to eq(['the-app-guid', 'the-app-guid2'])
        expect(message.guids).to eq(['process-guid', 'process-guid2'])
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
        expect(message.requested?(:guids)).to be_truthy
        expect(message.requested?(:order_by)).to be_truthy
      end
    end

    describe '#to_param_hash' do
      let(:opts) do
        {
          types:              ['bits', 'docker'],
          space_guids:        ['spaceguid1', 'spaceguid2'],
          app_guids:          ['appguid1', 'appguid2'],
          organization_guids: ['organizationguid1', 'organizationguid2'],
          guids:              ['processguid1'],
          app_guid:           'appguid',
          page:               1,
          per_page:           5,
          order_by:           'created_at',
        }
      end

      it 'excludes the pagination keys' do
        expected_params = [:types, :app_guids, :space_guids, :organization_guids, :guids]
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
            guids:              ['processguid'],
            app_guid:           'appguid',
            page:               1,
            per_page:           5,
            order_by:           'created_at',
          })
        }.not_to raise_error
      end

      it 'accepts an empty set' do
        message = ProcessesListMessage.new
        expect(message).to be_valid
      end

      it 'does not accept a field not in this set' do
        message = ProcessesListMessage.new(foobar: 'pants')

        expect(message).not_to be_valid
        expect(message.errors[:base]).to include("Unknown query parameter(s): 'foobar'")
      end
    end

    describe 'validations' do
      context 'app guids' do
        it 'validates app_guids is an array' do
          message = ProcessesListMessage.new app_guids: 'tricked you, not an array'
          expect(message).to be_invalid
          expect(message.errors[:app_guids]).to include('must be an array')
        end

        context 'app nested requests' do
          context 'user provides app_guids' do
            it 'is not valid' do
              message = ProcessesListMessage.new(app_guid: 'blah', app_guids: ['app1', 'app2'])
              expect(message).to_not be_valid
              expect(message.errors[:base]).to include("Unknown query parameter(s): 'app_guids'")
            end
          end

          context 'user provides organization_guids' do
            it 'is not valid' do
              message = ProcessesListMessage.new(app_guid: 'blah', organization_guids: ['orgguid1', 'orgguid2'])
              expect(message).to_not be_valid
              expect(message.errors[:base]).to include("Unknown query parameter(s): 'organization_guids'")
            end
          end

          context 'user provides space guids' do
            it 'is not valid' do
              message = ProcessesListMessage.new(app_guid: 'blah', space_guids: ['space1', 'space2'])
              expect(message).to_not be_valid
              expect(message.errors[:base]).to include("Unknown query parameter(s): 'space_guids'")
            end
          end
        end
      end
    end
  end
end
