require 'spec_helper'
require 'messages/droplet_update_message'

module VCAP::CloudController
  RSpec.describe DropletUpdateMessage do
    let(:body) do
      {
        'metadata' => {
          'labels' => {
            'potatoes' => 'taterTots'
          }
        }
      }
    end

    describe 'metadata' do
      it 'can parse labels and annotations' do
        params =
          {
            "metadata": {
              "labels": {
                "potato": 'mashed'
              },
              "annotations": {
                "eating": 'potatoes'
              }
            }
          }
        message = DropletUpdateMessage.new(params)
        expect(message).to be_valid
        expect(message.labels).to include("potato": 'mashed')
        expect(message.annotations).to include("eating": 'potatoes')
      end

      it 'validates both bad labels and bad annotations' do
        params = {
          "metadata": {
            "annotations": 'potato',
            "labels": 'fries'
          }
        }
        message = DropletUpdateMessage.new(params)
        expect(message).not_to be_valid
        expect(message.errors_on(:metadata)).to match_array(["'annotations' is not a hash", "'labels' is not a hash"])
      end
    end
  end
end
