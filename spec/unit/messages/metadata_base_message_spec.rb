require 'spec_helper'
require 'messages/metadata_base_message'

module VCAP::CloudController
  RSpec.describe MetadataBaseMessage do
    describe '#metadata' do
      let(:fake_class) do
        Class.new(MetadataBaseMessage) do
          register_allowed_keys []
        end
      end

      it 'can parse labels' do
        params =
          {
            "metadata": {
              "labels": {
                "potato": 'mashed'
              }
            }
          }
        message = fake_class.new(params)
        expect(message).to be_valid
        expect(message.labels).to include("potato": 'mashed')
      end

      it 'validates labels' do
        params = {
          "metadata": {
            "labels": 'potato',
          }
        }
        message = fake_class.new(params)
        expect(message).not_to be_valid
        expect(message.errors_on(:metadata)).to include("'labels' is not a hash")
      end
    end
  end
end
