require "spec_helper"

module VCAP::CloudController
  describe ServiceBrokerClient do
    let(:endpoint_base) { 'http://example.com' }
    let(:request_id) { 'req-id' }
    let(:token) { 'sometoken' }
    let(:client) { ServiceBrokerClient.new(endpoint_base, token) }

    before do
      stub_request(:any, endpoint_base)
      VCAP::Request.stub(:current_id).and_return(request_id)
    end

    describe "#catalog" do

      let(:expected_response) do
        {
          'services' => [
            {
              'id' => service_id,
              'name' => service_name,
              'description' => service_description,
              'plans' => [
                {
                  'id' => plan_id,
                  'name' => plan_name,
                  'description' => plan_description
                }
              ]
            }
          ]
        }
      end
      let(:service_id) { Sham.guid }
      let(:service_name) { Sham.name }
      let(:service_description) { Sham.description }

      let(:plan_id) { Sham.guid }
      let(:plan_name) { Sham.name }
      let(:plan_description) { Sham.description }

      it 'fetches the broker catalog' do
        stub_request(:get, "http://cc:sometoken@example.com/v2/catalog").
          with(headers: { 'X-VCAP-Request-ID' => request_id }).
          to_return(body: expected_response.to_json)

        catalog = client.catalog

        expect(catalog).to eq(expected_response)
      end
    end

    describe "#provision" do
      let(:reference_id) { 'ref_id' }
      let(:broker_service_instance_id) { 'broker_created_id' }
      let(:service_id) { 'some-service-id' }
      let(:plan_id) { 'some-plan-id' }

      let(:expected_request_body) do
        {
          service_id: service_id,
          plan_id: plan_id,
          reference_id: reference_id,
        }.to_json
      end
      let(:expected_response_body) do
        {
          id: broker_service_instance_id
        }.to_json
      end

      it 'calls the provision endpoint' do
        stub_request(:post, "http://cc:sometoken@example.com/v2/service_instances").
          with(body: expected_request_body, headers: { 'X-VCAP-Request-ID' => request_id }).
          to_return(body: expected_response_body)

        result = client.provision(service_id, plan_id, reference_id)

        expect(result['id']).to eq(broker_service_instance_id)
      end

      context 'the reference_id is already in use' do
        it 'raises ServiceBrokerConflict' do
          stub_request(:post, "http://cc:sometoken@example.com/v2/service_instances").
            to_return(status: 409)  # 409 is CONFLICT

          expect { client.provision(service_id, plan_id, reference_id) }.to raise_error(VCAP::Errors::ServiceBrokerConflict)
        end
      end
    end
  end
end
