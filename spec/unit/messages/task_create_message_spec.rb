require 'spec_helper'
require 'messages/task_create_message'

module VCAP::CloudController
  describe TaskCreateMessage do
    describe '.create_from_http_request' do
      let(:body) do
        {
          'name': 'mytask',
          'command': 'rake db:migrate && true',
          'droplet_guid': Sham.guid,
          'environment_variables' => {
            'ENVVAR' => 'env-val'
          },
          'memory_in_mb' => 2048
        }
      end

      it 'returns the correct TaskCreateMessage' do
        message = TaskCreateMessage.create_from_http_request(body)

        expect(message).to be_a(TaskCreateMessage)
        expect(message.name).to eq('mytask')
        expect(message.command).to eq('rake db:migrate && true')
        expect(message.environment_variables).to eq({ 'ENVVAR' => 'env-val' })
        expect(message.memory_in_mb).to eq(2048)
      end

      describe 'validations' do
        it 'validates that there are not excess fields' do
          body[:bogus] = 'field'
          message = TaskCreateMessage.create_from_http_request(body)

          expect(message).to_not be_valid
          expect(message.errors.full_messages).to include("Unknown field(s): 'bogus'")
        end

        describe 'droplet_guid' do
          it 'can be nil' do
            body.delete 'droplet_guid'

            message = TaskCreateMessage.create_from_http_request(body)

            expect(message).to be_valid
          end

          it 'must be a valid guid' do
            body[:droplet_guid] = 32913

            message = TaskCreateMessage.create_from_http_request(body)

            expect(message).to_not be_valid
          end
        end

        describe 'memory_in_mb' do
          it 'can be nil' do
            body.delete 'memory_in_mb'

            message = TaskCreateMessage.create_from_http_request(body)

            expect(message).to be_valid
          end

          it 'must be numerical' do
            body[:memory_in_mb] = 'trout'

            message = TaskCreateMessage.create_from_http_request(body)

            expect(message).to_not be_valid
            expect(message.errors.full_messages).to include('Memory in mb is not a number')
          end

          it 'may not have a floating point' do
            body[:memory_in_mb] = 4.5

            message = TaskCreateMessage.create_from_http_request(body)

            expect(message).to_not be_valid
            expect(message.errors.full_messages).to include('Memory in mb must be an integer')
          end

          it 'may not be negative' do
            body[:memory_in_mb] = -1

            message = TaskCreateMessage.create_from_http_request(body)

            expect(message).to_not be_valid
            expect(message.errors.full_messages).to include('Memory in mb must be greater than 0')
          end

          it 'may not be zero' do
            body[:memory_in_mb] = 0

            message = TaskCreateMessage.create_from_http_request(body)

            expect(message).to_not be_valid
            expect(message.errors.full_messages).to include('Memory in mb must be greater than 0')
          end
        end
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
