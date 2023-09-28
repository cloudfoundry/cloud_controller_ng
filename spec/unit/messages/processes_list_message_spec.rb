require 'spec_helper'
require 'messages/processes_list_message'

module VCAP::CloudController
  RSpec.describe ProcessesListMessage do
    describe '.from_params' do
      let(:params) do
        {
          'page' => 1,
          'per_page' => 5,
          'app_guid' => 'some-app-guid',
          'types' => 'web,worker',
          'space_guids' => 'the_space_guid,another-space-guid',
          'organization_guids' => 'the_organization_guid, another-org-guid',
          'app_guids' => 'the-app-guid, the-app-guid2',
          'guids' => 'process-guid,process-guid2',
          'order_by' => 'created_at',
          'label_selector' => 'key=value',
          'created_ats' => "#{Time.now.utc.iso8601},#{Time.now.utc.iso8601}",
          'updated_ats' => { gt: Time.now.utc.iso8601 }
        }
      end

      it 'parses comma-delimited filter keys into arrays' do
        message = ProcessesListMessage.from_params(params)

        expect(message).to be_a(ProcessesListMessage)
        expect(message.page).to eq(1)
        expect(message.per_page).to eq(5)
        expect(message.app_guid).to eq('some-app-guid')
        expect(message.types).to eq(%w[web worker])
        expect(message.space_guids).to eq(%w[the_space_guid another-space-guid])
        expect(message.organization_guids).to eq(%w[the_organization_guid another-org-guid])
        expect(message.app_guids).to eq(%w[the-app-guid the-app-guid2])
        expect(message.guids).to eq(%w[process-guid process-guid2])
        expect(message.label_selector).to eq('key=value')
      end

      it 'converts requested keys to symbols' do
        message = ProcessesListMessage.from_params(params)

        expect(message).to be_requested(:page)
        expect(message).to be_requested(:per_page)
        expect(message).to be_requested(:app_guid)
        expect(message).to be_requested(:types)
        expect(message).to be_requested(:space_guids)
        expect(message).to be_requested(:organization_guids)
        expect(message).to be_requested(:app_guids)
        expect(message).to be_requested(:guids)
        expect(message).to be_requested(:order_by)
        expect(message).to be_requested(:updated_ats)
        expect(message).to be_requested(:created_ats)
      end
    end

    describe '#to_param_hash' do
      let(:opts) do
        {
          types: %w[bits docker],
          space_guids: %w[spaceguid1 spaceguid2],
          app_guids: %w[appguid1 appguid2],
          organization_guids: %w[organizationguid1 organizationguid2],
          guids: ['processguid1'],
          app_guid: 'appguid',
          page: 1,
          label_selector: 'key=value',
          per_page: 5,
          order_by: 'created_at',
          created_ats: [Time.now.utc.iso8601, Time.now.utc.iso8601],
          updated_ats: { gt: Time.now.utc.iso8601 }
        }
      end

      it 'excludes the pagination keys' do
        expected_params = %i[
          types
          app_guids
          space_guids
          organization_guids
          guids
          label_selector
          created_ats
          updated_ats
        ]
        message = ProcessesListMessage.from_params(opts)

        expect(message.to_param_hash.keys).to match_array(expected_params)
      end
    end

    describe 'fields' do
      it 'accepts a set of fields' do
        expect do
          ProcessesListMessage.from_params({
                                             types: %w[bits docker],
                                             space_guids: %w[spaceguid1 spaceguid2],
                                             app_guids: %w[appguid1 appguid2],
                                             organization_guids: %w[organizationguid1 organizationguid2],
                                             guids: ['processguid'],
                                             app_guid: 'appguid',
                                             page: 1,
                                             per_page: 5,
                                             order_by: 'created_at'
                                           })
        end.not_to raise_error
      end

      it 'accepts an empty set' do
        message = ProcessesListMessage.from_params({})
        expect(message).to be_valid
      end

      it 'does not accept a field not in this set' do
        message = ProcessesListMessage.from_params(foobar: 'pants')

        expect(message).not_to be_valid
        expect(message.errors[:base][0]).to include("Unknown query parameter(s): 'foobar'")
      end
    end

    describe 'validations' do
      context 'app guids' do
        it 'validates app_guids is an array' do
          message = ProcessesListMessage.from_params app_guids: 'tricked you, not an array'
          expect(message).not_to be_valid
          expect(message.errors[:app_guids]).to include('must be an array')
        end

        context 'app nested requests' do
          context 'user provides app_guids' do
            it 'is not valid' do
              message = ProcessesListMessage.from_params(app_guid: 'blah', app_guids: %w[app1 app2])
              expect(message).not_to be_valid
              expect(message.errors[:base][0]).to include("Unknown query parameter(s): 'app_guids'")
            end
          end

          context 'user provides organization_guids' do
            it 'is not valid' do
              message = ProcessesListMessage.from_params(app_guid: 'blah', organization_guids: %w[orgguid1 orgguid2])
              expect(message).not_to be_valid
              expect(message.errors[:base][0]).to include("Unknown query parameter(s): 'organization_guids'")
            end
          end

          context 'user provides space guids' do
            it 'is not valid' do
              message = ProcessesListMessage.from_params(app_guid: 'blah', space_guids: %w[space1 space2])
              expect(message).not_to be_valid
              expect(message.errors[:base][0]).to include("Unknown query parameter(s): 'space_guids'")
            end
          end
        end
      end

      it 'validates metadata requirements' do
        message = ProcessesListMessage.from_params('label_selector' => '')

        expect_any_instance_of(Validators::LabelSelectorRequirementValidator).
          to receive(:validate).
          with(message).
          and_call_original
        message.valid?
      end
    end
  end
end
