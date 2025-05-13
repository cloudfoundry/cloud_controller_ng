require 'spec_helper'

module VCAP::CloudController
  RSpec.describe ManifestFeaturesUpdateMessage do
    subject(:message) { ManifestFeaturesUpdateMessage.new(params) }

    describe 'validations' do
      context 'when an unexpected key is requested' do
        let(:params) { { unexpected: 'key' } }

        it 'is not valid' do
          expect(message).not_to be_valid
          expect(message.errors.full_messages[0]).to include("Unknown field(s): 'unexpected'")
        end
      end

      context "when 'features' is not a hash" do
        let(:params) { { features: 'no hash' } }

        it 'is not valid' do
          expect(message).not_to be_valid
          expect(message.errors[:features]).to include('must be a map of valid feature names to booleans (true = enabled, false = disabled)')
        end
      end

      context "when the 'features' hash is empty" do
        let(:params) { { features: {} } }

        it 'is not valid' do
          expect(message).not_to be_valid
          expect(message.errors[:features]).to include('must be a map of valid feature names to booleans (true = enabled, false = disabled)')
        end
      end

      context "when the 'features' hash contains an invalid feature" do
        let(:params) { { features: { invalid_feature: true } } }

        it 'is not valid' do
          expect(message).not_to be_valid
          expect(message.errors[:features]).to include('must be a map of valid feature names to booleans (true = enabled, false = disabled)')
        end
      end

      context "when the 'features' hash contains an invalid 'enabled' value" do
        let(:params) { { features: { ssh: 'sure' } } }

        it 'is not valid' do
          expect(message).not_to be_valid
          expect(message.errors[:features]).to include('must be a map of valid feature names to booleans (true = enabled, false = disabled)')
        end
      end

      context "when 'features' are given in the right format" do
        let(:params) { { features: { ssh: true } } }

        it 'is valid' do
          expect(message).to be_valid
        end
      end
    end
  end
end
