require 'spec_helper'
require 'messages/droplet_create_message'

module VCAP::CloudController
  describe DropletCreateMessage do
    describe '.create_from_http_request' do
      let(:body) { { 'memory_limit' => 10 } }

      it 'returns the correct DropletCreateMessage' do
        message = DropletCreateMessage.create_from_http_request(body)

        expect(message).to be_a(DropletCreateMessage)
        expect(message.memory_limit).to eq(10)
      end

      it 'converts requested keys to symbols' do
        message = DropletCreateMessage.create_from_http_request(body)

        expect(message.requested?(:memory_limit)).to be_truthy
      end
    end

    describe 'validations' do
      context 'when unexpected keys are requested' do
        let(:params) do
          {
            unexpected: 'meow',
            lifecycle: { type: 'buildpack', data: { buildpack: 'java', stack: 'cflinuxfs2' } }
          }
        end

        it 'is not valid' do
          message = DropletCreateMessage.new(params)

          expect(message).not_to be_valid
          expect(message.errors.full_messages[0]).to include("Unknown field(s): 'unexpected'")
        end
      end

      context 'when memory_limit is not an number' do
        let(:params) do
          {
            memory_limit: 'silly string thing',
            lifecycle: { type: 'buildpack', data: { buildpack: 'java', stack: 'cflinuxfs2' } }
          }
        end

        it 'is not valid' do
          message = DropletCreateMessage.new(params)

          expect(message).not_to be_valid
          expect(message.errors[:memory_limit]).to include('is not a number')
        end
      end

      context 'when memory_limit is not an integer' do
        let(:params) do
          {
            memory_limit: 3.5,
            lifecycle: { type: 'buildpack', data: { buildpack: 'java', stack: 'cflinuxfs2' } }
          }
        end

        it 'is not valid' do
          message = DropletCreateMessage.new(params)

          expect(message).not_to be_valid
          expect(message.errors[:memory_limit]).to include('must be an integer')
        end
      end

      context 'when disk_limit is not an number' do
        let(:params) do
          {
            disk_limit: 'not-a-number',
            lifecycle: { type: 'buildpack', data: { buildpack: 'java', stack: 'cflinuxfs2' } }
          }
        end

        it 'is not valid' do
          message = DropletCreateMessage.new(params)

          expect(message).not_to be_valid
          expect(message.errors[:disk_limit]).to include('is not a number')
        end
      end

      context 'when disk_limit is not an integer' do
        let(:params) do
          {
            disk_limit: 3.5,
            lifecycle: { type: 'buildpack', data: { buildpack: 'java', stack: 'cflinuxfs2' } }
          }
        end

        it 'is not valid' do
          message = DropletCreateMessage.new(params)

          expect(message).not_to be_valid
          expect(message.errors[:disk_limit]).to include('must be an integer')
        end
      end

      context 'when environment_variables is not a hash' do
        let(:params) do
          {
            environment_variables: 'not-a-hash',
            lifecycle: { type: 'buildpack', data: { buildpack: 'java', stack: 'cflinuxfs2' } }
          }
        end

        it 'is not valid' do
          message = DropletCreateMessage.new(params)

          expect(message).not_to be_valid
          expect(message.errors[:environment_variables]).to include('must be a hash')
        end
      end

      context 'when lifecycle is provided' do
        it 'is valid' do
          params = { lifecycle: { type: 'buildpack', data: { buildpack: 'java', stack: 'cflinuxfs2' } } }
          message = DropletCreateMessage.new(params)
          expect(message).to be_valid
        end

        it 'must provide data' do
          params = { lifecycle: { type: 'buildpack' } }

          message = DropletCreateMessage.new(params)
          expect(message).not_to be_valid
          expect(message.errors[:lifecycle]).to include('data must be present')
          expect(message.errors[:lifecycle_data]).to include('must be a hash')
        end

        it 'must provide type' do
          params = { lifecycle: { data: { buildpack: 'java', stack: 'cflinuxfs2' } } }

          message = DropletCreateMessage.new(params)
          expect(message).not_to be_valid
          expect(message.errors[:lifecycle_type]).to include("can't be blank")
        end

        it 'must be a valid lifecycle type' do
          params = { lifecycle: { data: {}, type: { subhash: 'woah!' } } }

          message = DropletCreateMessage.new(params)

          expect(message).not_to be_valid
          expect(message.errors[:lifecycle_type]).to include('is not included in the list')
        end

        it 'must provide a valid stack' do
          params = { lifecycle: { type: 'buildpack', data: { buildpack: 'java', stack: { non: 'sense' } } } }

          message = DropletCreateMessage.new(params)

          expect(message).not_to be_valid
          expect(message.errors[:lifecycle]).to include('Stack must be a string')
        end

        it 'must be in the database' do
          params = { lifecycle: { type: 'buildpack', data: { buildpack: 'java', stack: 'redhat' } } }

          message = DropletCreateMessage.new(params)

          expect(message).not_to be_valid
          expect(message.errors[:lifecycle]).to include('Stack is invalid')
        end

        it 'must provide a valid buildpack' do
          params = { lifecycle: { type: 'buildpack', data: { buildpack: { wh: 'at?' }, stack: 'onstacksonstacks' } } }

          message = DropletCreateMessage.new(params)

          expect(message).not_to be_valid
          expect(message.errors[:lifecycle]).to include('Buildpack must be a string')
        end
      end
    end
  end
end
