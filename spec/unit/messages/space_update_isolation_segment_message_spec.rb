require 'spec_helper'
require 'messages/space_update_isolation_segment_message'

module VCAP::CloudController
  RSpec.describe SpaceUpdateIsolationSegmentMessage do
    describe 'validations' do
      context 'when there is no guid in the data' do
        let(:symbolized_body) do
          {
            data: {}
          }
        end

        it 'returns an error' do
          message = SpaceUpdateIsolationSegmentMessage.new(symbolized_body)

          expect(message).not_to be_valid
          expect(message.errors[:data]).to include("can't be blank")
        end
      end

      context 'when data is nil' do
        let(:symbolized_body) do
          {
            data: nil
          }
        end

        it 'does not error and returns the correct message' do
          message = SpaceUpdateIsolationSegmentMessage.new(symbolized_body)

          expect(message).to be_a(SpaceUpdateIsolationSegmentMessage)
          expect(message).to be_valid
          expect(message.isolation_segment_guid).to be_nil
        end
      end

      context 'when unexpected keys are requested' do
        let(:symbolized_body) do
          {
            unexpected: 'an-unexpected-value'
          }
        end

        it 'is not valid' do
          message = SpaceUpdateIsolationSegmentMessage.new(symbolized_body)

          expect(message).not_to be_valid
          expect(message.errors[:base]).to include("Unknown field(s): 'unexpected'")
        end

        context 'when there are unexpected keys inside data hash' do
          let(:symbolized_body) do
            {
              data: { blah: 'awesome-guid' }
            }
          end

          it 'is not valid' do
            message = SpaceUpdateIsolationSegmentMessage.new(symbolized_body)

            expect(message).not_to be_valid
            expect(message.errors[:data]).to include("can only accept key 'guid'")
          end
        end

        context 'when there are multiple keys inside data hash' do
          let(:symbolized_body) do
            {
              data: { blah: 'awesome-guid', glob: 'super-guid' }
            }
          end

          it 'is not valid' do
            message = SpaceUpdateIsolationSegmentMessage.new(symbolized_body)

            expect(message).not_to be_valid
            expect(message.errors[:data]).to include('can only accept one key')
          end
        end

        context 'when the guid is not a string' do
          let(:symbolized_body) do
            {
              data: { guid: 32.77 }
            }
          end

          it 'is not valid' do
            message = SpaceUpdateIsolationSegmentMessage.new(symbolized_body)

            expect(message).not_to be_valid
            expect(message.errors[:data]).not_to include("can only accept key 'guid'")
            expect(message.errors[:data]).to include('32.77 must be a string')
          end
        end
      end
    end
  end
end
