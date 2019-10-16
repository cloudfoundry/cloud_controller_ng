require 'spec_helper'
require 'messages/validators/authentication_validator'

module VCAP::CloudController::Validators
  RSpec.describe 'AuthenticationValidator' do
    let(:class_with_authentication) do
      Class.new do
        include ActiveModel::Model
        validates_with AuthenticationValidator

        attr_accessor :authentication
      end
    end

    subject(:message) do
      class_with_authentication.new(authentication: authentication)
    end

    context 'when authentication.type is invalid' do
      let(:authentication) do
        {
          type: 'oopsie'
        }
      end

      it 'is not valid' do
        expect(message).not_to be_valid
        expect(message.errors_on(:authentication_type)).to include('authentication.type must be one of ["basic"]')
      end
    end

    context 'when username and password are missing from credentials' do
      let(:authentication) do
        {
          type: 'basic',
          credentials: {
          },
        }
      end

      it 'is not valid' do
        expect(message).not_to be_valid
        expect(message.errors_on(:authentication_credentials)).to include(/Field\(s\) \["username", "password"\] must be valid/)
      end
    end

    context 'when credentials is missing from authentication' do
      let(:authentication) do
        {
          type: 'basic'
        }
      end

      it 'is not valid' do
        expect(message).not_to be_valid
        expect(message.errors_on(:authentication_credentials)).to include('must be an object')
      end
    end

    context 'when credentials is not an object' do
      let(:authentication) do
        {
          type: 'basic',
          credentials: []
        }
      end

      it 'is not valid' do
        expect(message).not_to be_valid
        expect(message.errors_on(:authentication_credentials)).to include('must be an object')
      end
    end

    context 'when authentication has extra fields' do
      let(:authentication) do
        {
          extra: 'value',
          type: 'basic',
        }
      end

      it 'is not valid' do
        expect(message).not_to be_valid
        expect(message.errors_on(:authentication)).to include("Unknown field(s): 'extra'")
      end
    end

    context 'when just password is in credentials' do
      let(:authentication) do
        {
          credentials: {
            password: 'password'
          },
        }
      end

      it 'is not valid' do
        expect(message).not_to be_valid
        expect(message.errors_on(:authentication_credentials)).to include(/Field\(s\) \["username"\] must be valid/)
      end
    end

    context 'when just username is in credentials' do
      let(:authentication) do
        {
          credentials: {
            username: 'user'
          },
        }
      end

      it 'is not valid' do
        expect(message).not_to be_valid
        expect(message.errors_on(:authentication_credentials)).to include(/Field\(s\) \["password"\] must be valid/)
      end
    end
  end
end
