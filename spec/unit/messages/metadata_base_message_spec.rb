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
      context 'when the message contains labels' do
        it 'can parse labels' do
          params =
            {
              metadata: {
                labels: {
                  potato: 'mashed'
                }
              }
            }
          message = fake_class.new(params)
          expect(message).to be_valid
          expect(message.labels).to include(potato: 'mashed')
        end

        it 'validates labels' do
          params = {
            metadata: {
              labels: 'potato',
            }
          }
          message = fake_class.new(params)
          expect(message).not_to be_valid
          expect(message.errors_on(:metadata)).to include("'labels' is not an object")
        end
      end

      context 'when the message contains annotations' do
        it 'can parse annotations' do
          params =
            {
              metadata: {
                annotations: {
                  potato: 'mashed'
                }
              }
            }
          message = fake_class.new(params)
          expect(message).to be_valid
          expect(message.annotations).to include(potato: 'mashed')
        end

        it 'validates annotations' do
          params = {
            metadata: {
              annotations: 'potato',
            }
          }
          message = fake_class.new(params)
          expect(message).not_to be_valid
          expect(message.errors_on(:metadata)).to include("'annotations' is not an object")
        end
      end
    end
  end
end
