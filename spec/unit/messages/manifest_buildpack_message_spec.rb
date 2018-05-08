require 'spec_helper'
require 'messages/manifest_buildpack_message'

module VCAP::CloudController
  RSpec.describe ManifestBuildpackMessage do
    subject(:message) { ManifestBuildpackMessage.new(params) }

    describe 'validations' do
      context 'when unexpected keys are requested' do
        let(:params) { { unexpected: 'foo', extra: 'bar', ports: [8181] } }

        it 'is not valid' do
          expect(message).not_to be_valid
          expect(message.errors.full_messages[0]).to include("Unknown field(s): 'unexpected', 'extra', 'ports'")
        end
      end

      context 'when buildpack is not a string' do
        let(:params) { { buildpack: 32.77 } }

        it 'is not valid' do
          expect(message).not_to be_valid
          expect(message.errors[:buildpack]).to include('must be a string')
        end
      end

      context 'when buildpack is too long' do
        let(:params) { { buildpack: 'a' * 4097 } }

        it 'is not valid' do
          expect(message).not_to be_valid
          expect(message.errors[:buildpack]).to include('must be between 1 and 4096 characters')
        end
      end

      context 'when buildpack is empty' do
        let(:params) { { buildpack: '' } }

        it 'is not valid' do
          expect(message).not_to be_valid
          expect(message.errors[:buildpack]).to include('must be between 1 and 4096 characters')
        end
      end
    end
  end
end
