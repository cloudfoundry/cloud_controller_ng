require 'spec_helper'
require 'messages/isolation_segment_relationship_org_message'

module VCAP::CloudController
  RSpec.describe IsolationSegmentRelationshipOrgMessage do
    describe 'validations' do
      context 'where there are no guids in the data' do
        let(:params) do
          {
            data: []
          }
        end

        it 'returns an error' do
          message = IsolationSegmentRelationshipOrgMessage.new(params)

          expect(message).to_not be_valid
          expect(message.errors[:data]).to include("can't be blank")
        end
      end

      context 'when data is not an array' do
        let(:params) do
          {
            data: 'boo'
          }
        end

        it 'returns an error' do
          message = IsolationSegmentRelationshipOrgMessage.new(params)

          expect(message).to_not be_valid
          expect(message.errors[:data]).to include('must be an array')
        end
      end

      context 'when unexpected keys are requested' do
        let(:params) {
          {
            unexpected: 'an-unexpected-value',
          }
        }

        it 'is not valid' do
          message = IsolationSegmentRelationshipOrgMessage.new(params)

          expect(message).to_not be_valid
          expect(message.errors[:base]).to include("Unknown field(s): 'unexpected'")
        end

        context 'when the guid is not a string' do
          let(:params) do
            {
              data: [
                { guid: 32.77 }
              ]
            }
          end

          it 'is not valid' do
            message = IsolationSegmentRelationshipOrgMessage.new(params)

            expect(message).not_to be_valid
            expect(message.errors[:data]).to include('32.77 not a string')
          end
        end
      end
    end
  end
end
