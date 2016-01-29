require 'spec_helper'
require 'messages/task_create_message'

module VCAP::CloudController
  describe TaskCreateMessage do
    describe '.create' do
      let(:body) do
        {
          'name': 'mytask',
          'command': 'rake db:migrate && true',
          'environment_variables' => {
            'ENVVAR' => 'env-val'
          },
          'memory_in_mb' => 2048
        }
      end

      it 'returns the correct TaskCreateMessage' do
        message = TaskCreateMessage.create(body)

        expect(message).to be_a(TaskCreateMessage)
        expect(message.name).to eq('mytask')
        expect(message.command).to eq('rake db:migrate && true')
        expect(message.environment_variables).to eq({ 'ENVVAR' => 'env-val' })
        expect(message.memory_in_mb).to eq(2048)
      end

      it 'validates that there are not excess fields' do
        body.merge! 'bogus': 'field'
        message = TaskCreateMessage.create(body)

        expect(message).to_not be_valid
        expect(message.errors.full_messages).to include("Unknown field(s): 'bogus'")
      end

      context 'when environment_variables is not a hash' do
        let(:params) do
          {
            name:                  'name',
            environment_variables: 'potato',
            relationships:         { space: { guid: 'guid' } },
            lifecycle: {
              type: 'buildpack',
              data: {
                buildpack: 'nil',
                stack: Stack.default.name
              }
            }
          }
        end

        it 'is not valid' do
          message = AppCreateMessage.new(params)

          expect(message).not_to be_valid
          expect(message.errors_on(:environment_variables)).to include('must be a hash')
        end
      end
    end
  end
end
