require 'spec_helper'
require 'messages/orgs/organization_create_message'

module VCAP::CloudController
  RSpec.describe OrganizationCreateMessage do
    let(:body) do
      {
        'name' => 'my-org',
      }
    end

    describe '.create_from_http_request' do
      it 'returns the correct OrganizationCreateMessage' do
        message = OrganizationCreateMessage.create_from_http_request(body)

        expect(message).to be_a(OrganizationCreateMessage)
        expect(message.name).to eq('my-org')
      end
    end

    describe 'validations' do
      it 'validates that there are not excess fields' do
        body['bogus'] = 'field'
        message = OrganizationCreateMessage.create_from_http_request(body)

        expect(message).to_not be_valid
        expect(message.errors.full_messages).to include("Unknown field(s): 'bogus'")
      end

      describe 'name' do
        it 'validates that it is a string' do
          body = { name: 1 }
          message = OrganizationCreateMessage.create_from_http_request(body)

          expect(message).to_not be_valid
          expect(message.errors.full_messages).to include('Name must be a string')
        end

        describe 'allowed special characters' do
          it 'allows standard ascii characters' do
            body = { name: "A -_- word 2!?()\'\"&+." }
            message = OrganizationCreateMessage.create_from_http_request(body)
            expect(message).to be_valid
          end

          it 'allows backslash characters' do
            body = { name: 'a\\word' }
            message = OrganizationCreateMessage.create_from_http_request(body)
            expect(message).to be_valid
          end

          it 'allows unicode characters' do
            body = { name: '防御力¡' }
            message = OrganizationCreateMessage.create_from_http_request(body)
            expect(message).to be_valid
          end

          it 'does NOT allow newline characters' do
            body = { name: "one\ntwo" }
            message = OrganizationCreateMessage.create_from_http_request(body)
            expect(message).to_not be_valid
            expect(message.errors.full_messages).to include('Name must not contain escaped characters')
          end

          it 'does NOT allow escape characters' do
            body = { name: "a\e word" }
            message = OrganizationCreateMessage.create_from_http_request(body)
            expect(message).to_not be_valid
            expect(message.errors.full_messages).to include('Name must not contain escaped characters')
          end
        end

        it 'must be present' do
          body = {}
          message = OrganizationCreateMessage.create_from_http_request(body)
          expect(message).to_not be_valid
          expect(message.errors.full_messages).to include("Name can't be blank")
        end

        it 'must be <= 255 characters long' do
          body = { name: 'a' * 256 }
          message = OrganizationCreateMessage.create_from_http_request(body)
          expect(message).to_not be_valid
          expect(message.errors.full_messages).to include('Name is too long (maximum is 255 characters)')

          body = { name: 'a' * 255 }
          message = OrganizationCreateMessage.create_from_http_request(body)
          expect(message).to be_valid
        end
      end
    end
  end
end
