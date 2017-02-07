require 'spec_helper'
require 'messages/isolation_segments/isolation_segment_create_message'

module VCAP::CloudController
  RSpec.describe IsolationSegmentCreateMessage do
    describe '.create_from_http_request' do
      let(:body) {
        {
          'name' => 'some-name',
        }
      }

      it 'returns the correct IsolationSegmentMessage' do
        message = IsolationSegmentCreateMessage.create_from_http_request(body)

        expect(message).to be_a(IsolationSegmentCreateMessage)
        expect(message.name).to eq('some-name')
      end

      it 'converts requested keys to symbols' do
        message = IsolationSegmentCreateMessage.create_from_http_request(body)

        expect(message.requested?(:name)).to be_truthy
      end
    end

    describe 'validations' do
      context 'when unexpected keys are requested' do
        let(:params) {
          {
            name: 'some-name',
            unexpected: 'an-unexpected-value',
          }
        }

        it 'is not valid' do
          message = IsolationSegmentCreateMessage.new(params)

          expect(message).to_not be_valid
          expect(message.errors[:base]).to include("Unknown field(s): 'unexpected'")
        end

        context 'when the name is not a string' do
          let(:params) do
            {
              name: 32.77,
            }
          end

          it 'is not valid' do
            message = IsolationSegmentCreateMessage.new(params)

            expect(message).not_to be_valid
            expect(message.errors_on(:name)).to include('must be a string')
          end
        end
      end
    end
  end
end
