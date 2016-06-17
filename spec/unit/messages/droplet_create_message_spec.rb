require 'spec_helper'
require 'messages/droplet_create_message'

module VCAP::CloudController
  RSpec.describe DropletCreateMessage do
    describe '.create_from_http_request' do
      let(:body) { { 'staging_memory_in_mb' => 10 } }

      it 'returns the correct DropletCreateMessage' do
        message = DropletCreateMessage.create_from_http_request(body)

        expect(message).to be_a(DropletCreateMessage)
        expect(message.staging_memory_in_mb).to eq(10)
      end

      it 'converts requested keys to symbols' do
        message = DropletCreateMessage.create_from_http_request(body)

        expect(message.requested?(:staging_memory_in_mb)).to be true
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

      context 'when staging_memory_in_mb is not an number' do
        let(:params) do
          {
            staging_memory_in_mb: 'silly string thing',
            lifecycle: { type: 'buildpack', data: { buildpack: 'java', stack: 'cflinuxfs2' } }
          }
        end

        it 'is not valid' do
          message = DropletCreateMessage.new(params)

          expect(message).not_to be_valid
          expect(message.errors[:staging_memory_in_mb]).to include('is not a number')
        end
      end

      context 'when staging_memory_in_mb is not an integer' do
        let(:params) do
          {
            staging_memory_in_mb: 3.5,
            lifecycle: { type: 'buildpack', data: { buildpack: 'java', stack: 'cflinuxfs2' } }
          }
        end

        it 'is not valid' do
          message = DropletCreateMessage.new(params)

          expect(message).not_to be_valid
          expect(message.errors[:staging_memory_in_mb]).to include('must be an integer')
        end
      end

      context 'when staging_disk_in_mb is not an number' do
        let(:params) do
          {
            staging_disk_in_mb: 'not-a-number',
            lifecycle: { type: 'buildpack', data: { buildpack: 'java', stack: 'cflinuxfs2' } }
          }
        end

        it 'is not valid' do
          message = DropletCreateMessage.new(params)

          expect(message).not_to be_valid
          expect(message.errors[:staging_disk_in_mb]).to include('is not a number')
        end
      end

      context 'when staging_disk_in_mb is not an integer' do
        let(:params) do
          {
            staging_disk_in_mb: 3.5,
            lifecycle: { type: 'buildpack', data: { buildpack: 'java', stack: 'cflinuxfs2' } }
          }
        end

        it 'is not valid' do
          message = DropletCreateMessage.new(params)

          expect(message).not_to be_valid
          expect(message.errors[:staging_disk_in_mb]).to include('must be an integer')
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

        it 'must provide type' do
          params = { lifecycle: { data: { buildpack: 'java', stack: 'cflinuxfs2' } } }

          message = DropletCreateMessage.new(params)
          expect(message).not_to be_valid
          expect(message.errors[:lifecycle_type]).to include('must be a string')
        end

        it 'must be a valid lifecycle type' do
          params = { lifecycle: { data: {}, type: { subhash: 'woah!' } } }

          message = DropletCreateMessage.new(params)

          expect(message).not_to be_valid
          expect(message.errors[:lifecycle_type]).to include('must be a string')
        end

        it 'must provide a data field' do
          params = { lifecycle: { type: 'buildpack' } }

          message = DropletCreateMessage.new(params)

          expect(message).not_to be_valid
          expect(message.errors[:lifecycle_data]).to include('must be a hash')
        end

        describe 'buildpack lifecycle' do
          it 'must provide a valid stack' do
            params = { lifecycle: { type: 'buildpack', data: { buildpack: 'java', stack: { non: 'sense' } } } }

            message = DropletCreateMessage.new(params)

            expect(message).not_to be_valid
            expect(message.errors[:lifecycle]).to include('Stack must be a string')
          end

          it 'must provide a valid buildpack' do
            params = { lifecycle: { type: 'buildpack', data: { buildpack: { wh: 'at?' }, stack: 'onstacksonstacks' } } }

            message = DropletCreateMessage.new(params)

            expect(message).not_to be_valid
            expect(message.errors[:lifecycle]).to include('Buildpack must be a string')
          end
        end

        describe 'docker lifecycle' do
          it 'works' do
            params  = { lifecycle: { type: 'docker', data: {} } }
            message = DropletCreateMessage.new(params)
            expect(message).to be_valid
          end
        end
      end
    end
  end
end
