require 'spec_helper'
require 'messages/tasks_list_message'

module VCAP::CloudController
  RSpec.describe TasksListMessage do
    describe '.from_params' do
      let(:params) do
        {
          'names'              => 'name1,name2',
          'states'             => 'FAILED,SUCCEEDED',
          'guids'              => 'guid1,guid2',
          'app_guids'          => 'appguid',
          'organization_guids' => 'orgguid',
          'space_guids'        => 'spaceguid',
          'page'               => 1,
          'per_page'           => 5,
          'app_guid'           => 'blah-blah',
          'sequence_ids'       => '1,2'
        }
      end

      it 'returns the correct TaskListMessage' do
        message = TasksListMessage.from_params(params)

        expect(message).to be_a(TasksListMessage)
        expect(message.names).to eq(['name1', 'name2'])
        expect(message.states).to eq(['FAILED', 'SUCCEEDED'])
        expect(message.guids).to eq(['guid1', 'guid2'])
        expect(message.app_guids).to eq(['appguid'])
        expect(message.organization_guids).to eq(['orgguid'])
        expect(message.space_guids).to eq(['spaceguid'])
        expect(message.page).to eq(1)
        expect(message.per_page).to eq(5)
        expect(message.app_guid).to eq('blah-blah')
        expect(message.sequence_ids).to eq(['1', '2'])
      end

      it 'converts requested keys to symbols' do
        message = TasksListMessage.from_params(params)

        expect(message.requested?(:names)).to be_truthy
        expect(message.requested?(:states)).to be_truthy
        expect(message.requested?(:guids)).to be_truthy
        expect(message.requested?(:app_guids)).to be_truthy
        expect(message.requested?(:organization_guids)).to be_truthy
        expect(message.requested?(:space_guids)).to be_truthy
        expect(message.requested?(:page)).to be_truthy
        expect(message.requested?(:per_page)).to be_truthy
        expect(message.requested?(:app_guid)).to be_truthy
        expect(message.requested?(:sequence_ids)).to be_truthy
      end
    end

    describe '#to_param_hash' do
      let(:opts) do
        {
          names:              ['name1', 'name2'],
          states:             ['SUCCEDED', 'FAILED'],
          guids:              ['guid1', 'guid2'],
          app_guids:          ['appguid1', 'appguid2'],
          organization_guids: ['orgguid1', 'orgguid2'],
          space_guids:        ['spaceguid1', 'spaceguid2'],
          sequence_ids:       ['1, 2'],
          page:               1,
          per_page:           5,
        }
      end

      it 'excludes the pagination keys' do
        expected_params = [:names, :states, :guids, :app_guids, :organization_guids, :space_guids, :sequence_ids]
        expect(TasksListMessage.new(opts).to_param_hash.keys).to match_array(expected_params)
      end
    end

    describe 'fields' do
      it 'accepts a set of fields' do
        message = TasksListMessage.new({
          names:              [],
          states:             [],
          guids:              [],
          app_guids:          [],
          organization_guids: [],
          space_guids:        [],
          page:               1,
          per_page:           5,
        })
        expect(message).to be_valid
      end

      it 'accepts an empty set' do
        message = TasksListMessage.new
        expect(message).to be_valid
      end

      it 'does not accept a field not in this set' do
        message = TasksListMessage.new({ foobar: 'pants' })

        expect(message).not_to be_valid
        expect(message.errors[:base]).to include("Unknown query parameter(s): 'foobar'")
      end

      describe 'validations' do
        describe 'validating app nested query' do
          context 'when the request contains app_guid but not app_guids, space_guids, and org_guids' do
            it 'validates' do
              message = TasksListMessage.new({ app_guid: 'blah' })
              expect(message).to be_valid
            end
          end

          context 'when the request does not contain app_guid but space_guids, org_guids, and app_guids' do
            it 'validates' do
              message = TasksListMessage.new({ app_guids: ['1'], space_guids: ['2'], organization_guids: ['5'] })
              expect(message).to be_valid
            end
          end

          context 'when the request contains both app_guid and app_guids' do
            it 'does not validate' do
              message = TasksListMessage.new({ app_guid: 'blah', app_guids: ['app1', 'app2'] })
              expect(message).to_not be_valid
              expect(message.errors[:base]).to include("Unknown query parameter(s): 'app_guids'")
            end
          end

          context 'when the request contains both app_guid and space_guids' do
            it 'does not validate' do
              message = TasksListMessage.new({ app_guid: 'blah', space_guids: ['space1', 'space2'] })
              expect(message).to_not be_valid
              expect(message.errors[:base]).to include("Unknown query parameter(s): 'space_guids'")
            end
          end

          context 'when the request contains both app_guid and org_guids' do
            it 'does not validate' do
              message = TasksListMessage.new({ app_guid: 'blah', organization_guids: ['org1', 'org2'] })
              expect(message).to_not be_valid
              expect(message.errors[:base]).to include("Unknown query parameter(s): 'organization_guids'")
            end
          end

          context 'when the request contains both app_guid and app_guids, space_guids, and org_guids' do
            it 'does not validate' do
              message = TasksListMessage.new({
                app_guid: 'blah',
                app_guids: ['app1', 'app2'],
                space_guids: ['space1', 'space2'],
                organization_guids: ['org1', 'org2']
              })
              expect(message).to_not be_valid
              expect(message.errors[:base]).to include("Unknown query parameter(s): 'space_guids', 'organization_guids', 'app_guids'")
            end
          end

          it 'validates sequence_ids is an array' do
            message = TasksListMessage.new sequence_ids: 'not array'
            expect(message).to be_invalid
            expect(message.errors[:sequence_ids].length).to eq 1
          end
        end

        it 'validates names is an array' do
          message = TasksListMessage.new names: 'not array'
          expect(message).to be_invalid
          expect(message.errors[:names].length).to eq 1
        end

        it 'validates states is an array' do
          message = TasksListMessage.new states: 'not array'
          expect(message).to be_invalid
          expect(message.errors[:states].length).to eq 1
        end

        it 'validates guids is an array' do
          message = TasksListMessage.new guids: 'not array'
          expect(message).to be_invalid
          expect(message.errors[:guids].length).to eq 1
        end

        it 'validates app_guids is an array' do
          message = TasksListMessage.new app_guids: 'not array'
          expect(message).to be_invalid
          expect(message.errors[:app_guids].length).to eq 1
        end

        it 'validates organization_guids is an array' do
          message = TasksListMessage.new organization_guids: 'not array'
          expect(message).to be_invalid
          expect(message.errors[:organization_guids].length).to eq 1
        end

        it 'validates space_guids is an array' do
          message = TasksListMessage.new space_guids: 'not array'
          expect(message).to be_invalid
          expect(message.errors[:space_guids].length).to eq 1
        end

        it 'does not allow sequence_ids' do
          message = TasksListMessage.new sequence_ids: [1]
          expect(message).to be_invalid
          expect(message.errors[:base]).to include("Unknown query parameter(s): 'sequence_ids'")
        end
      end
    end
  end
end
