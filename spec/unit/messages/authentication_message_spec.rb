require 'lightweight_spec_helper'
require 'active_model'
require 'rspec/collection_matchers'
require 'messages/authentication_message'

module VCAP::CloudController
  RSpec.describe AuthenticationMessage do
    subject { AuthenticationMessage }

    context 'authentication' do
      let(:valid_body) do
        {
          type: 'basic',
          credentials: {
            username: 'user',
            password: 'pass',
          }
        }
      end

      let(:message) { AuthenticationMessage.new(request_body) }

      context 'when type is invalid' do
        let(:request_body) do
          valid_body.merge({
            type: 'oopsie'
          })
        end

        it 'is not valid' do
          expect(message).not_to be_valid
          expect(message.errors_on(:type)).to include('authentication.type must be one of ["basic"]')
        end
      end

      context 'when credentials are missing from authentication' do
        let(:request_body) do
          valid_body.delete(:credentials)
          valid_body
        end

        it 'is not valid' do
          expect(message).not_to be_valid
          expect(message.errors_on(:credentials)).to include('must be an object')
        end
      end

      context 'when authentication has extra fields' do
        let(:request_body) do
          valid_body.merge({
            extra: 'value',
            type: 'basic',
          })
        end

        it 'is not valid' do
          expect(message).not_to be_valid
          expect(message.errors_on(:base)).to include("Unknown field(s): 'extra'")
        end
      end
    end
  end
end
