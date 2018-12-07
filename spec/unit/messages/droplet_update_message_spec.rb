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
      it 'can parse labels' do
        params =
          {
            "metadata": {
              "labels": {
                "potato": 'mashed'
              }
            }
          }
        message = DropletUpdateMessage.new(params)
        expect(message).to be_valid
        expect(message.labels).to include("potato": 'mashed')
      end

      it 'validates labels' do
        params = {
          "metadata": {
            "labels": 'potato',
          }
        }
        message = DropletUpdateMessage.new(params)
        expect(message).not_to be_valid
        expect(message.errors_on(:metadata)).to include("'labels' is not a hash")
      end
    end
  end
end
