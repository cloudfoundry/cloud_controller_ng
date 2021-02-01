require 'spec_helper'
require 'messages/deployment_update_message'

module VCAP::CloudController
  RSpec.describe DeploymentUpdateMessage do
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
            metadata: {
              labels: {
                potato: 'mashed'
              },
              annotations: {
                eating: 'potatoes'
              }
            }
          }
        message = DeploymentUpdateMessage.new(params)
        expect(message).to be_valid
        expect(message.labels).to include(potato: 'mashed')
        expect(message.annotations).to include(eating: 'potatoes')
      end

      it 'validates both bad labels and bad annotations' do
        params = {
          metadata: {
            annotations: 'potato',
            labels: 'fries'
          }
        }
        message = DeploymentUpdateMessage.new(params)
        expect(message).not_to be_valid
        expect(message.errors_on(:metadata)).to match_array(["'annotations' is not an object", "'labels' is not an object"])
      end
    end
  end
end
