require 'spec_helper'
require 'messages/droplet_update_message'

module VCAP::CloudController
  RSpec.describe DropletUpdateMessage do
    let(:body) do
      {
        'image' => 'some-image-reference',
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
            image: 'new-image-reference',
            metadata: {
              labels: {
                potato: 'mashed'
              },
              annotations: {
                eating: 'potatoes'
              }
            }
          }
        message = DropletUpdateMessage.new(params)
        expect(message).to be_valid
        expect(message.labels).to include(potato: 'mashed')
        expect(message.annotations).to include(eating: 'potatoes')
        expect(message.image).to eq('new-image-reference')
      end

      it 'validates both bad labels and bad annotations' do
        params = {
          metadata: {
            annotations: 'potato',
            labels: 'fries'
          }
        }
        message = DropletUpdateMessage.new(params)
        expect(message).not_to be_valid
        expect(message.errors_on(:metadata)).to match_array(["'annotations' is not an object", "'labels' is not an object"])
      end

      it 'validates bad image references' do
        params = {
          image: { blah: 34234 }
        }
        message = DropletUpdateMessage.new(params)
        expect(message).not_to be_valid
        expect(message.errors_on(:image)).to match_array(['must be a string'])
      end
    end
  end
end
