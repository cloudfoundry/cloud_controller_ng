require 'spec_helper'
require 'messages/internal_build_update_message'

module VCAP::CloudController
  RSpec.describe InternalBuildUpdateMessage do
    let(:body) do
      {
        state: 'STAGED',
        error: 'error'
      }
    end

    describe 'validations' do
      it 'confirms state and error are valid' do
        message = InternalBuildUpdateMessage.new(body)

        expect(message).to be_valid
      end

      context 'null error' do
        let(:body) do
          {
            state: 'STAGED'
          }
        end

        it 'allows a null error' do
          message = InternalBuildUpdateMessage.new(body)

          expect(message).to be_valid
        end
      end

      it 'validates that there are not excess fields' do
        body['bogus'] = 'field'
        message = InternalBuildUpdateMessage.new(body)

        expect(message).to_not be_valid
        expect(message.errors.full_messages).to include("Unknown field(s): 'bogus'")
      end

      context 'state is invalid' do
        let(:body) do
          {
            state: 'something',
            error: 'error'
          }
        end

        it 'complains if state is not valid' do
          message = InternalBuildUpdateMessage.new(body)

          expect(message).not_to be_valid
          expect(message.errors[:state]).to include("'something' is not a valid state")
        end
      end

      context 'error is invalid' do
        let(:body) do
          {
            state: 'STAGED',
            error: {
              is_a: 'hash'
            }
          }
        end

        it 'complains if error is not valid' do
          message = InternalBuildUpdateMessage.new(body)

          expect(message).not_to be_valid
          expect(message.errors[:error]).to include('must be a string')
        end
      end

      it 'complains about bogus metadata fields' do
        newbody = body.merge({ "metadata": { "choppers": 3 } })
        message = InternalBuildUpdateMessage.new(newbody)

        expect(message).not_to be_valid
      end
    end
  end
end
