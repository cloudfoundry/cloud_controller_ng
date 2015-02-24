require 'spec_helper'

module VCAP::Services
  module ServiceBrokers::V1
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
      let(:url) { 'http://broker.example.com' }

      subject(:client) do
        HttpClient.new(
          url: url,
          auth_token: auth_token
        )
      end

      before do
        allow(HttpClient).to receive(:new).and_call_original
        allow(VCAP::Request).to receive(:current_id).and_return(request_id)
      end

      describe 'http client timeout' do
        let(:http) { double('http', request: response) }
        let(:response) { Net::HTTPOK.new('1.0', 200, nil) }
        let(:unique_id) { Sham.guid }
        let(:name)      { Sham.name }
        let(:expected_response) do
          {
            'service_id' => '456',
            'configuration' => { 'setting' => true },
            'credentials' => { 'user' => 'admin', 'pass' => 'secret' }
          }.to_json
        end

        def expect_timeout_to_be(timeout)
          expect(http).to receive(:open_timeout=).with(timeout)
          expect(http).to receive(:read_timeout=).with(timeout)
        end

        before do
          allow(VCAP::CloudController::Config).to receive(:config).and_return(config)
          allow(Net::HTTP).to receive(:start).and_yield(http)
          allow(response).to receive(:body).and_return(expected_response)
        end

        context 'when the broker client timeout is set' do
          let(:config) { { broker_client_timeout_seconds: 100 } }

          it 'sets HTTP timeouts on provisions' do
            expect_timeout_to_be 100
            client.provision(unique_id, name)
          end
        end
      end

      context 'when an https URL is used' do
        let(:url) { 'https://broker.example.com' }
        it 'uses SSL' do
          stub_request(:post, 'https://broker.example.com/gateway/v1/configurations').
              to_return(status: 200, body: '', headers: {})
          client.provision('unique_id', 'name')
          expect(WebMock).to have_requested(:post, 'https://broker.example.com/gateway/v1/configurations')
        end
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
            'configuration' => { 'setting' => true },
            'credentials' => { 'user' => 'admin', 'pass' => 'secret' }
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
        let(:app_id) { Sham.guid }
        let(:label) { Sham.label }
        let(:email) { Sham.email }
        let(:binding_options) { Sham.binding_options }
        let(:bind_url) { "http://broker.example.com/gateway/v1/configurations/#{instance_id}/handles" }

        let(:expected_request_body) do
          {
            service_id: instance_id,
            app_id: app_id,
            label: label,
            email: email,
            binding_options: binding_options,
          }.to_json
        end

        let(:binding_id) { Sham.guid }

        let(:expected_response) do
          {
            'service_id' => binding_id,
            'configuration' => { 'setting' => true },
            'credentials' => { 'user' => 'admin', 'pass' => 'secret' }
          }
        end

        it 'sends a POST to /gateway/v1/configurations/:instance_id/handles' do
          request = stub_request(:post, bind_url).
            with(body: expected_request_body, headers: expected_request_headers).
            to_return(status: 200, body: expected_response.to_json)

          response = client.bind(instance_id, app_id, label, email, binding_options)

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

        context 'when the broker returns a structured error' do
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
              expect(error_hash.fetch('description')).to eq('Service broker error: This is what really happened.')
              expect(error_hash.fetch('source')).to eq(expected_source)
              expect(error_hash.fetch('http')).to eq(expected_http)
            }
          end
        end

        context 'when the broker returns a structured error without a description' do
          let(:error_status) { 500 }
          let(:error_body) do
            {
              'foo' => 'bar'
            }.to_json
          end

          before do
            stub_request(request_method, request_url).
              to_return(status: [error_status, 'Internal Server Error'], body: error_body)
          end

          it 'raises an HttpResponseError with the source and http information' do
            expect {
              client.provision('someid', 'somename')
            }.to raise_error(HttpResponseError) { |error|
              expected_source = {
                'foo' => 'bar'
              }
              expected_http = {
                'status' => error_status,
                'uri' => request_url,
                'method' => 'POST',
              }

              error_hash = error.to_h
              expect(error_hash.fetch('description')).to eq("The service broker API returned an error from #{request_url}: 500 Internal Server Error")
              expect(error_hash.fetch('source')).to eq(expected_source)
              expect(error_hash.fetch('http')).to eq(expected_http)
            }
          end
        end
      end
    end
  end
end
