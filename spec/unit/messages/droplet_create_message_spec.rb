require 'spec_helper'
require 'messages/droplet_create_message'

module VCAP::CloudController
  describe DropletCreateMessage do
    describe '.create_from_http_request' do
      let(:body) { { 'memory_limit' => 10 } }

      it 'returns the correct PackageCreateMessage' do
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
        let(:params) { { unexpected: 'foo' } }

        it 'is not valid' do
          message = DropletCreateMessage.new(params)

          expect(message).not_to be_valid
          expect(message.errors.full_messages[0]).to include("Unknown field(s): 'unexpected'")
        end
      end

      context 'when memory_limit is not an number' do
        let(:params) { { memory_limit: 'silly string thing' } }

        it 'is not valid' do
          message = DropletCreateMessage.new(params)

          expect(message).not_to be_valid
          expect(message.errors.full_messages[0]).to include('is not a number')
        end
      end

      context 'when memory_limit is not an integer' do
        let(:params) { { memory_limit: 3.5 } }

        it 'is not valid' do
          message = DropletCreateMessage.new(params)

          expect(message).not_to be_valid
          expect(message.errors.full_messages[0]).to include('must be an integer')
        end
      end

      context 'when disk_limit is not an number' do
        let(:params) { { disk_limit: 'silly string thing' } }

        it 'is not valid' do
          message = DropletCreateMessage.new(params)

          expect(message).not_to be_valid
          expect(message.errors.full_messages[0]).to include('is not a number')
        end
      end

      context 'when disk_limit is not an integer' do
        let(:params) { { disk_limit: 3.5 } }

        it 'is not valid' do
          message = DropletCreateMessage.new(params)

          expect(message).not_to be_valid
          expect(message.errors.full_messages[0]).to include('must be an integer')
        end
      end

      context 'when stack is not a string' do
        let(:params) { { stack: 32.77 } }

        it 'is not valid' do
          message = DropletCreateMessage.new(params)

          expect(message).not_to be_valid
          expect(message.errors.full_messages[0]).to include('must be a string')
        end
      end

      context 'when stack is nil' do
        let(:params) { { stack: nil } }

        it 'is not valid' do
          message = DropletCreateMessage.new(params)

          expect(message).not_to be_valid
          expect(message.errors.full_messages[0]).to include('must be a string')
        end
      end

      context 'when stack is too long' do
        let(:params) { { stack: 'a' * 5098 } }

        it 'is not valid' do
          message = DropletCreateMessage.new(params)

          expect(message).not_to be_valid
          expect(message.errors.full_messages[0]).to include('must be between 1 and 4096 characters')
        end
      end

      context 'when stack is empty' do
        let(:params) { { stack: '' } }

        it 'is not valid' do
          message = DropletCreateMessage.new(params)

          expect(message).not_to be_valid
          expect(message.errors.full_messages[0]).to include('must be between 1 and 4096 characters')
        end
      end

      context 'when buildpack_git_url is not a valid url' do
        let(:params) { { buildpack_git_url: 'blagow!' } }

        it 'is not valid' do
          message = DropletCreateMessage.new(params)

          expect(message).not_to be_valid
          expect(message.errors.full_messages[0]).to include('must be a valid URI')
        end
      end

      context 'when buildpack_guid is not a guid' do
        let(:params) { { buildpack_guid: 34 } }

        it 'is not valid' do
          message = DropletCreateMessage.new(params)

          expect(message).not_to be_valid
        end
      end

      context 'when both buildpack_git_url and buildpack_guid are provided' do
        let(:params) { { buildpack_guid: 'some-guid', buildpack_git_url: 'http://www.slashdot.org' } }

        it 'is not valid' do
          message = DropletCreateMessage.new(params)

          expect(message).not_to be_valid
          expect(message.errors.full_messages[0]).to include('Only one of buildpack_git_url or buildpack_guid may be provided')
        end
      end
    end
  end
end
