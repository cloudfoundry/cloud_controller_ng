require 'spec_helper'
require 'credhub/client'

module Credhub
  RSpec.describe Client do
    let(:credhub_url) { 'https://credhub.example.com:8844' }
    let(:uaa_token_auth_header) { 'bearer token' }
    let(:token_info) { instance_double(CF::UAA::TokenInfo, auth_header: uaa_token_auth_header) }
    let(:uaa_client) { instance_double(VCAP::CloudController::UaaClient, token_info: token_info) }
    let(:credhub_reference) { 'my-cred-reference' }

    subject { Credhub::Client.new(credhub_url, uaa_client) }

    describe '#get_credential_by_name' do
      before do
        stub_request(:get, "#{credhub_url}/api/v1/data?name=#{credhub_reference}&current=true").
          with(headers: {
            'Authorization' => uaa_token_auth_header,
            'Content-Type'  => 'application/json'
          }).to_return(status: status, body: credhub_response)
      end

      context 'when the client can access the credential' do
        let(:status) { 200 }
        let(:credhub_response) do
          '{
            "data": [
              {
                "value": {
                  "password": "tinytim",
                  "user-name": "adminannie"
                }
              }
            ]
          }'
        end

        context 'when the credential exists' do
          it 'returns the credential' do
            expect(subject.get_credential_by_name(credhub_reference)).to eq('user-name' => 'adminannie', 'password' => 'tinytim')
          end
        end

        context 'when the credential does not exist' do
          let(:status) { 404 }
          let(:credhub_response) do
            '{
              "error": "The request could not be completed because the credential does not exist or you do not have sufficient authorization."
            }'
          end

          it 'raises Credhub::CredentialNotFoundError' do
            expect { subject.get_credential_by_name(credhub_reference) }.
              to raise_error(Credhub::CredentialNotFoundError, /credential does not exist or you do not have sufficient authorization/)
          end
        end
      end

      context 'when the client does not have access to the credential' do
        let(:status) { 403 }
        let(:credhub_response) do
          '{
              "error": "The request could not be completed because the credential does not exist or you do not have sufficient authorization."
            }'
        end

        it 'raises Credhub::ForbiddenError' do
          expect { subject.get_credential_by_name(credhub_reference) }.
            to raise_error(Credhub::ForbiddenError, /credential does not exist or you do not have sufficient authorization/)
        end
      end

      context 'when the client is not authenticated' do
        let(:status) { 401 }
        let(:credhub_response) do
          '{"error":"invalid_token","error_description":"Full authentication is required to access this resource"}'
        end

        it 'raises Credhub::UnauthenticatedError' do
          expect { subject.get_credential_by_name(credhub_reference) }.
            to raise_error(Credhub::UnauthenticatedError, /Full authentication is required to access this resource/)
        end
      end

      context 'when CredHub returns a bad response' do
        let(:status) { 500 }
        let(:credhub_response) { 'invalid-broken-json' }

        it 'raises a Credhub::BadResponseError' do
          expect { subject.get_credential_by_name(credhub_reference) }.
            to raise_error(Credhub::BadResponseError, /Server error/)
        end
      end
    end
  end
end
