require 'spec_helper'
require 'messages/tasks_list_message'

module VCAP::CloudController
  describe TasksListMessage do
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
          page:               1,
          per_page:           5,
        }
      end

      it 'excludes the pagination keys' do
        expected_params = [:names, :states, :guids, :app_guids, :organization_guids, :space_guids]
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

        describe 'page' do
          it 'validates it is a number' do
            message = TasksListMessage.new page: 'not number'
            expect(message).to be_invalid
            expect(message.errors[:page].length).to eq 1
          end

          it 'is invalid if page is 0' do
            message = TasksListMessage.new page: 0
            expect(message).to be_invalid
            expect(message.errors[:page].length).to eq 1
          end

          it 'is invalid if page is negative' do
            message = TasksListMessage.new page: -1
            expect(message).to be_invalid
            expect(message.errors[:page].length).to eq 1
          end

          it 'is invalid if page is not an integer' do
            message = TasksListMessage.new page: 1.1
            expect(message).to be_invalid
            expect(message.errors[:page].length).to eq 1
          end
        end

        describe 'per_page' do
          it 'validates it is a number' do
            message = TasksListMessage.new per_page: 'not number'
            expect(message).to be_invalid
            expect(message.errors[:per_page].length).to eq 1
          end

          it 'is invalid if per_page is 0' do
            message = TasksListMessage.new per_page: 0
            expect(message).to be_invalid
            expect(message.errors[:per_page].length).to eq 1
          end

          it 'is invalid if per_page is negative' do
            message = TasksListMessage.new per_page: -1
            expect(message).to be_invalid
            expect(message.errors[:per_page].length).to eq 1
          end

          it 'is invalid if per_page is not an integer' do
            message = TasksListMessage.new per_page: 1.1
            expect(message).to be_invalid
            expect(message.errors[:per_page].length).to eq 1
          end
        end
      end
    end
  end
end
