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

    describe "#catalog"

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
        it 'does something meaningful' do

        end
      end
    end
  end
end
