require 'spec_helper'

module VCAP::CloudController
  module ServiceBroker::V1
    describe HttpClient do
      let(:auth_token) { 'abc123' }
      let(:request_id) { Sham.guid }
      let(:expected_request_headers) do
        {
          'X-VCAP-Request-ID' => request_id,
          'X-VCAP-Service-Token' => auth_token,
          'Accept' => 'application/json',
          'Content-Type' => 'application/json'
        }
      end

      subject(:client) do
        HttpClient.new(
          url: 'http://broker.example.com',
          auth_token: auth_token
        )
      end

      before do
        HttpClient.unstub(:new)
        VCAP::Request.stub(:current_id).and_return(request_id)
      end

      describe '#provision' do
        let(:instance_id) { Sham.guid }
        let(:plan_id) { Sham.guid }
        let(:email) { Sham.email }
        let(:provider) { Sham.provider }
        let(:label) { Sham.label }
        let(:plan) { Sham.guid }
        let(:version) { Sham.version }
        let(:organization_guid) { Sham.guid }
        let(:space_guid) { Sham.guid }
        let(:provision_url) { 'http://broker.example.com/gateway/v1/configurations' }

        let(:expected_request_body) do
          {
            'email' => email,
            'provider' => provider,
            'label' => label,
            'plan' => plan,
            'version' => version,
            'organization_guid' => organization_guid,
            'space_guid' => space_guid,
            'unique_id' => plan_id,
            'name' => 'Example Service'
          }.to_json
        end

        let(:expected_response) do
          {
            'service_id' => '456',
            'configuration' => {'setting' => true},
            'credentials' => {'user' => 'admin', 'pass' => 'secret'}
          }
        end

        it 'sends a POST to /gateway/v1/configurations' do
          request = stub_request(:post, provision_url).
            with(body: expected_request_body, headers: expected_request_headers).
            to_return(status: 200, body: expected_response.to_json)

          response = client.provision(plan_id, 'Example Service', {
            email: email,
            provider: provider,
            label: label,
            plan: plan,
            version: version,
            organization_guid: organization_guid,
            space_guid: space_guid
          })

          expect(request).to have_been_made
          expect(response).to eq(expected_response)
        end
      end

      describe '#bind' do
        let(:instance_id) { Sham.guid }
        let(:label) { Sham.label }
        let(:email) { Sham.email }
        let(:binding_options) { Sham.binding_options }
        let(:bind_url) { "http://broker.example.com/gateway/v1/configurations/#{instance_id}/handles" }

        let(:expected_request_body) do
          {
            service_id: instance_id,
            label: label,
            email: email,
            binding_options: binding_options,
          }.to_json
        end

        let(:binding_id) { Sham.guid }

        let(:expected_response) do
          {
            'service_id' => binding_id,
            'configuration' => {'setting' => true},
            'credentials' => {'user' => 'admin', 'pass' => 'secret'}
          }
        end

        it 'sends a POST to /gateway/v1/configurations/:instance_id/handles' do
          request = stub_request(:post, bind_url).
            with(body: expected_request_body, headers: expected_request_headers).
            to_return(status: 200, body: expected_response.to_json)

          response = client.bind(instance_id, label, email, binding_options)

          expect(request).to have_been_made
          expect(response).to eq(expected_response)
        end
      end

      describe '#unbind' do
        let(:instance_id) { Sham.guid }
        let(:binding_id) { Sham.guid }
        let(:binding_options) { Sham.binding_options }
        let(:unbind_url) { "http://broker.example.com/gateway/v1/configurations/#{instance_id}/handles/#{binding_id}" }

        let(:expected_request_body) do
          {
            service_id: instance_id,
            handle_id: binding_id,
            binding_options: binding_options
          }.to_json
        end

        it 'sends a DELETE to /gateway/v1/configurations/:instance_id/handles/:binding_id' do
          request = stub_request(:delete, unbind_url).
            with(body: expected_request_body, headers: expected_request_headers).
            to_return(status: 200, body: '')

          response = client.unbind(instance_id, binding_id, binding_options)

          expect(request).to have_been_made
          expect(response).to be_nil
        end
      end

      describe '#deprovision' do
        let(:instance_id) { Sham.guid }
        let(:deprovision_url) { "http://broker.example.com/gateway/v1/configurations/#{instance_id}" }

        it 'sends a DELETE to /gateway/v1/configurations/:instance_id' do
          request = stub_request(:delete, deprovision_url).
            with(headers: expected_request_headers).
            to_return(status: 200, body: '')

          response = client.deprovision(instance_id)

          expect(request).to have_been_made
          expect(response).to be_nil
        end
      end

      describe 'error conditions' do
        let(:request_method) { :post }
        let(:request_url) { 'http://broker.example.com/gateway/v1/configurations' }

        context 'when the broker returns a structure error' do
          let(:error_status) { 500 }
          let(:error_body) do
            {
              'code' => 12345,
              'description' => 'This is what really happened.'
            }.to_json
          end

          before do
            stub_request(request_method, request_url).
              to_return(status: error_status, body: error_body)
          end

          it 'raises an HttpResponseError with the source and http information' do
            expect {
              client.provision('someid', 'somename')
            }.to raise_error(HttpResponseError) { |error|
              expected_source = {
                'code' => 12345,
                'description' => 'This is what really happened.'
              }
              expected_http = {
                'status' => error_status,
                'uri' => request_url,
                'method' => 'POST',
              }

              error_hash = error.to_h
              expect(error_hash.fetch('description')).to eq('500 error from broker')
              expect(error_hash.fetch('source')).to eq(expected_source)
              expect(error_hash.fetch('http')).to eq(expected_http)
            }
          end
        end
      end
    end
  end
end
