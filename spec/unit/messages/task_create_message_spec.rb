require 'spec_helper'
require 'messages/task_create_message'

module VCAP::CloudController
  RSpec.describe TaskCreateMessage do
    let(:process_guid) { Sham.guid }
    let(:body) do
      {
        'name' => 'mytask',
        'command' => 'rake db:migrate && true',
        'droplet_guid' => Sham.guid,
        'memory_in_mb' => 2048,
        'template' => {
          'process' => {
            'guid' => process_guid
          }
        },
        'metadata' => {
          'labels' => { 'gortz' => 'purple' },
          'annotations' => { 'potatoe' => 'quayle' }
        }
      }
    end

    describe 'validations' do
      it 'validates that there are not excess fields' do
        body['bogus'] = 'field'
        message = TaskCreateMessage.new(body)

        expect(message).not_to be_valid
        expect(message.errors.full_messages).to include("Unknown field(s): 'bogus'")
      end

      describe 'droplet_guid' do
        it 'can be nil' do
          body.delete 'droplet_guid'

          message = TaskCreateMessage.new(body)

          expect(message).to be_valid
        end

        it 'must be a valid guid' do
          body['droplet_guid'] = 32_913

          message = TaskCreateMessage.new(body)

          expect(message).not_to be_valid
        end
      end

      describe 'memory_in_mb' do
        it 'can be nil' do
          body.delete 'memory_in_mb'

          message = TaskCreateMessage.new(body)

          expect(message).to be_valid
        end

        it 'must be numerical' do
          body['memory_in_mb'] = 'trout'

          message = TaskCreateMessage.new(body)

          expect(message).not_to be_valid
          expect(message.errors.full_messages).to include('Memory in mb is not a number')
        end

        it 'may not have a floating point' do
          body['memory_in_mb'] = 4.5

          message = TaskCreateMessage.new(body)

          expect(message).not_to be_valid
          expect(message.errors.full_messages).to include('Memory in mb must be an integer')
        end

        it 'may not be negative' do
          body['memory_in_mb'] = -1

          message = TaskCreateMessage.new(body)

          expect(message).not_to be_valid
          expect(message.errors.full_messages).to include('Memory in mb must be greater than 0')
        end

        it 'may not be zero' do
          body['memory_in_mb'] = 0

          message = TaskCreateMessage.new(body)

          expect(message).not_to be_valid
          expect(message.errors.full_messages).to include('Memory in mb must be greater than 0')
        end
      end

      describe 'disk_in_mb' do
        it 'can be nil' do
          body.delete 'disk_in_mb'

          message = TaskCreateMessage.new(body)

          expect(message).to be_valid
        end

        it 'must be numerical' do
          body['disk_in_mb'] = 'trout'

          message = TaskCreateMessage.new(body)

          expect(message).not_to be_valid
          expect(message.errors.full_messages).to include('Disk in mb is not a number')
        end

        it 'may not have a floating point' do
          body['disk_in_mb'] = 4.5

          message = TaskCreateMessage.new(body)

          expect(message).not_to be_valid
          expect(message.errors.full_messages).to include('Disk in mb must be an integer')
        end

        it 'may not be negative' do
          body['disk_in_mb'] = -1

          message = TaskCreateMessage.new(body)

          expect(message).not_to be_valid
          expect(message.errors.full_messages).to include('Disk in mb must be greater than 0')
        end

        it 'may not be zero' do
          body['disk_in_mb'] = 0

          message = TaskCreateMessage.new(body)

          expect(message).not_to be_valid
          expect(message.errors.full_messages).to include('Disk in mb must be greater than 0')
        end
      end

      describe 'log_rate_limit_in_bytes_per_second' do
        it 'can be nil' do
          body.delete 'log_rate_limit_in_bytes_per_second'

          message = TaskCreateMessage.new(body)

          expect(message).to be_valid
        end

        it 'must be numerical' do
          body['log_rate_limit_in_bytes_per_second'] = 'trout'

          message = TaskCreateMessage.new(body)

          expect(message).not_to be_valid
          expect(message.errors.full_messages).to include('Log rate limit in bytes per second is not a number')
        end

        it 'may not have a floating point' do
          body['log_rate_limit_in_bytes_per_second'] = 4.5

          message = TaskCreateMessage.new(body)

          expect(message).not_to be_valid
          expect(message.errors.full_messages).to include('Log rate limit in bytes per second must be an integer')
        end

        it 'may be -1' do
          body['log_rate_limit_in_bytes_per_second'] = -1

          message = TaskCreateMessage.new(body)

          expect(message).to be_valid
        end

        it 'may be zero' do
          body['log_rate_limit_in_bytes_per_second'] = 0

          message = TaskCreateMessage.new(body)

          expect(message).to be_valid
        end

        it 'may not be smaller than -1' do
          body['log_rate_limit_in_bytes_per_second'] = -2

          message = TaskCreateMessage.new(body)

          expect(message).not_to be_valid
          expect(message.errors.full_messages).to include('Log rate limit in bytes per second must be greater than -2')
        end

        it 'may not be too large' do
          body['log_rate_limit_in_bytes_per_second'] = 2**63

          message = TaskCreateMessage.new(body)

          expect(message).not_to be_valid
          expect(message.errors.full_messages).to include('Log rate limit in bytes per second must be less than or equal to 9223372036854775807')
        end
      end

      describe 'template' do
        it 'can be nil' do
          body.delete 'template'

          message = TaskCreateMessage.new(body)

          expect(message).to be_valid
        end

        it 'is required when there is no command' do
          body.delete 'template'
          body.delete 'command'

          message = TaskCreateMessage.new(body)

          expect(message).not_to be_valid
        end

        it 'must be an object' do
          body['template'] = 'abc'

          message = TaskCreateMessage.new(body)

          expect(message).not_to be_valid
        end

        it 'must contain a process key' do
          body['template'] = {}

          message = TaskCreateMessage.new(body)

          expect(message).not_to be_valid
        end

        it 'must contain a process hash' do
          body['template'] = { 'process' => 'abc' }

          message = TaskCreateMessage.new(body)

          expect(message).not_to be_valid
        end

        it 'must contain a process has with a guid' do
          body['template'] = { 'process' => {} }

          message = TaskCreateMessage.new(body)

          expect(message).not_to be_valid
        end

        it 'must contain a process has with a valid guid' do
          body['template'] = { 'process' => { 'guid' => 32_913 } }

          message = TaskCreateMessage.new(body)

          expect(message).not_to be_valid
        end
      end

      describe '#template_process_guid' do
        context 'when a template is requested' do
          it 'returns the process guid' do
            message = TaskCreateMessage.new(body)

            expect(message.template_process_guid).to eq(process_guid)
          end
        end

        context 'when a template is NOT requested' do
          it 'returns nil' do
            body.delete 'template'

            message = TaskCreateMessage.new(body)

            expect(message.template_process_guid).to be_nil
          end
        end
      end
    end
  end
end
