require 'lightweight_spec_helper'
require 'active_model'
require 'rspec/collection_matchers'
require 'messages/basic_credentials_message'

module VCAP::CloudController
  RSpec.describe BasicCredentialsMessage do
    subject { BasicCredentialsMessage }

    let(:message) { BasicCredentialsMessage.new(request_body) }
    let(:request_body) do
      {
        username: 'user',
        password: 'password'
      }
    end

    it 'is valid when username and password is supplied' do
      expect(message).to be_valid
    end

    context 'when password is missing from credentials' do
      let(:request_body) do
        {
          username: 'user',
        }
      end

      it 'is not valid' do
        expect(message).not_to be_valid
        expect(message.errors_on(:password)).to include(/must be a string/)
      end
    end

    context 'when username is missing from credentials' do
      let(:request_body) do
        {
          password: 'password1',
        }
      end

      it 'is not valid' do
        expect(message).not_to be_valid
        expect(message.errors_on(:username)).to include(/must be a string/)
      end
    end
  end
end
