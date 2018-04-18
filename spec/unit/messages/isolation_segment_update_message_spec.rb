require 'spec_helper'
require 'messages/isolation_segment_update_message'

module VCAP::CloudController
  RSpec.describe IsolationSegmentUpdateMessage do
    describe 'validations' do
      context 'when unexpected keys are requested' do
        let(:params) {
          {
            name: 'some-name',
            unexpected: 'an-unexpected-value',
          }
        }

        it 'is not valid' do
          message = IsolationSegmentUpdateMessage.new(params)

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
            message = IsolationSegmentUpdateMessage.new(params)

            expect(message).not_to be_valid
            expect(message.errors_on(:name)).to include('must be a string')
          end
        end
      end
    end
  end
end
