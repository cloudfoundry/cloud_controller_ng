require 'spec_helper'
require 'messages/orgs/orgs_default_iso_seg_update_message'

module VCAP::CloudController
  RSpec.describe OrgDefaultIsoSegUpdateMessage do
    describe '.create_from_http_request' do
      let(:params) do
        { 'data' => { 'guid' => 'iso-seg-guid' } }
      end

      it 'returns the correct OrgsUpdateMessage' do
        message = OrgDefaultIsoSegUpdateMessage.create_from_http_request(params)

        expect(message).to be_a(OrgDefaultIsoSegUpdateMessage)
        expect(message.default_isolation_segment_guid).to eq('iso-seg-guid')
      end

      it 'converts a requested keys to symbols' do
        message = OrgDefaultIsoSegUpdateMessage.create_from_http_request(params)

        expect(message.requested?(:data)).to be_truthy
      end
    end

    describe 'validations' do
      context 'when there is no guid in the data' do
        let(:symbolized_body) do
          {
            data: {}
          }
        end

        it 'returns an error' do
          message = OrgDefaultIsoSegUpdateMessage.new(symbolized_body)

          expect(message).to_not be_valid
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
          message = OrgDefaultIsoSegUpdateMessage.new(symbolized_body)

          expect(message).to be_a(OrgDefaultIsoSegUpdateMessage)
          expect(message).to be_valid
          expect(message.default_isolation_segment_guid).to be_nil
        end
      end

      context 'when unexpected keys are requested' do
        let(:symbolized_body) {
          {
            unexpected: 'an-unexpected-value',
          }
        }

        it 'is not valid' do
          message = OrgDefaultIsoSegUpdateMessage.new(symbolized_body)

          expect(message).to_not be_valid
          expect(message.errors[:base]).to include("Unknown field(s): 'unexpected'")
        end

        context 'when there are unexpected keys inside data hash' do
          let(:symbolized_body) {
            {
              data: { blah: 'awesome-guid' },
            }
          }

          it 'is not valid' do
            message = OrgDefaultIsoSegUpdateMessage.new(symbolized_body)

            expect(message).to_not be_valid
            expect(message.errors[:data]).to include("can only accept key 'guid'")
          end
        end

        context 'when there are multiple keys inside data hash' do
          let(:symbolized_body) {
            {
              data: { blah: 'awesome-guid', glob: 'super-guid' },
            }
          }

          it 'is not valid' do
            message = OrgDefaultIsoSegUpdateMessage.new(symbolized_body)

            expect(message).to_not be_valid
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
            message = OrgDefaultIsoSegUpdateMessage.new(symbolized_body)

            expect(message).not_to be_valid
            expect(message.errors[:data]).not_to include("can only accept key 'guid'")
            expect(message.errors[:data]).to include('32.77 must be a string')
          end
        end
      end
    end
  end
end
