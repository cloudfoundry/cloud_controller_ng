require 'spec_helper'
require 'messages/named_app_manifest_message'

module VCAP::CloudController
  RSpec.describe NamedAppManifestMessage do
    describe 'validations' do
      context 'when unexpected keys are requested' do
        let(:params) { { name: 'hawaiian', instances: 3, memory: '2G' } }

        it 'is valid' do
          message = NamedAppManifestMessage.create_from_yml(params)

          expect(message).to be_valid
        end
      end

      context 'when name is not specified' do
        let(:params) { { instances: 3, memory: '2G' } }
        it 'is not valid' do
          message = NamedAppManifestMessage.create_from_yml(params)

          expect(message).to_not be_valid
        end
      end
    end
  end
end
