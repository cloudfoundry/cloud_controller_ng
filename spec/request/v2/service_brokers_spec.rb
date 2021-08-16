require 'spec_helper'

RSpec.describe 'ServiceBrokers' do
  describe 'PUT /v2/service_brokers' do
    context 'when ccng fails to parse the service broker endpoint' do
      let!(:service_broker) { VCAP::CloudController::ServiceBroker.make }
      before do
        stub_request(:get, 'https://broker.example.com/v2/catalog').
          to_return(status: 200, body: "<!doctype html>
                      <html>
                      <body>
                       i like cats
                      </body>
                      </html>")
      end

      it 'returns a descriptive error' do
        req_body = {
          broker_url: 'https://broker.example.com',
        }

        put "/v2/service_brokers/#{service_broker.guid}", req_body.to_json, admin_headers
        expect(last_response.status).to eq(502)
        expect(parsed_response['description']).
          to eq('The service broker returned an invalid response: expected valid JSON object in body. Please check that the URL points to a valid service broker.')
      end
    end

    context 'when the service broker endpoint returns an error' do
      let!(:service_broker) { VCAP::CloudController::ServiceBroker.make }
      before do
        stub_request(:get, 'https://broker.example.com/v2/catalog').
          to_return(status: 403, body: "<!doctype html>
                      <html>
                      <body>
                       i like cats
                      </body>
                      </html>")
      end

      it 'returns a descriptive error' do
        req_body = {
          broker_url: 'https://broker.example.com',
        }

        put "/v2/service_brokers/#{service_broker.guid}", req_body.to_json, admin_headers
        expect(last_response.status).to eq(502)
        expect(parsed_response['description']).
          to eq('The service broker rejected the request. Status Code: 403 Forbidden. Please check that the URL points to a valid service broker.')
      end
    end
  end

  describe 'POST /v2/service_brokers' do
    service_name = 'myservice'
    plan_name = 'myplan'

    context 'when ccng fails to parse the service broker endpoint' do
      before do
        stub_request(:get, 'https://broker.example.com/v2/catalog').
          to_return(status: 200, body: "<!doctype html>
                      <html>
                      <body>
                       i like cats
                      </body>
                      </html>")
      end

      it 'returns a descriptive error' do
        req_body = {
          name: 'service-broker-name',
          broker_url: 'https://broker.example.com',
          auth_username: 'admin',
          auth_password: 'secretpassw0rd'
        }

        post '/v2/service_brokers', req_body.to_json, admin_headers
        expect(last_response.status).to eq(502)
        expect(parsed_response['description']).
          to eq('The service broker returned an invalid response: expected valid JSON object in body. Please check that the URL points to a valid service broker.')
      end
    end

    context 'when the service broker endpoint returns an error' do
      before do
        stub_request(:get, 'https://broker.example.com/v2/catalog').
          to_return(status: 403, body: "<!doctype html>
                      <html>
                      <body>
                       i like cats
                      </body>
                      </html>")
      end

      it 'returns a descriptive error' do
        req_body = {
          name: 'service-broker-name',
          broker_url: 'https://broker.example.com',
          auth_username: 'admin',
          auth_password: 'secretpassw0rd'
        }

        post '/v2/service_brokers', req_body.to_json, admin_headers
        expect(last_response.status).to eq(502)
        expect(parsed_response['description']).
          to eq('The service broker rejected the request. Status Code: 403 Forbidden. Please check that the URL points to a valid service broker.')
      end
    end

    context 'when service broker is valid' do
      before do
        allow(VCAP::Services::ServiceBrokers::V2::Client).to receive(:new) do |*args, **kwargs, &block|
          fb = FakeServiceBrokerV2Client.new(*args, **kwargs, &block)
          fb.service_name = service_name
          fb.plan_name = plan_name
          fb
        end
      end

      it 'should register the service broker' do
        req_body = {
          name: 'service-broker-name',
          broker_url: 'https://broker.example.com',
          auth_username: 'admin',
          auth_password: 'secretpassw0rd'
        }

        post '/v2/service_brokers', req_body.to_json, admin_headers
        expect(last_response.status).to eq(201)

        broker = VCAP::CloudController::ServiceBroker.last
        expect(broker.name).to eq(req_body[:name])
        expect(broker.broker_url).to eq(req_body[:broker_url])
        expect(broker.auth_username).to eq(req_body[:auth_username])
        expect(broker.auth_password).to eq(req_body[:auth_password])

        service = VCAP::CloudController::Service.last
        expect(service.label).to eq(service_name)

        plan = VCAP::CloudController::ServicePlan.last
        expect(plan.name).to eq(plan_name)
      end

      context 'for brokers with schemas' do
        big_string = 'x' * 65 * 1024

        schemas = {
        'service_instance' => {
          'create' =>  {
            'parameters' => {
                'type' => 'object',
                'foo' => big_string
              }
            }
          }
        }

        before do
          allow(VCAP::Services::ServiceBrokers::V2::Client).to receive(:new) do |*args, **kwargs, &block|
            fb = FakeServiceBrokerV2Client.new(*args, **kwargs, &block)
            fb.plan_schemas = schemas
            fb
          end
        end

        it 'should not allow schema bigger than 64KB' do
          req_body = {
            name: 'service-broker-name',
            broker_url: 'https://broker.example.com',
            auth_username: 'admin',
            auth_password: 'secretpassw0rd'
          }

          post '/v2/service_brokers', req_body.to_json, admin_headers
          expect(last_response.status).to eq(502)
        end
      end
    end
  end
end
