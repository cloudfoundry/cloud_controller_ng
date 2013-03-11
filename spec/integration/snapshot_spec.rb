require File.expand_path("../../api/spec_helper", __FILE__)
require "services/api"

describe "Taking snapshots" do
  # FIXME: yuck, this is a manual unstub because of some other crap we did...
  before(:all) do
    @original_klass = VCAP::CloudController::Models::ServiceInstance.gateway_client_class
    VCAP::CloudController::Models::ServiceInstance.instance_eval { remove_instance_variable(:@gateway_client_class) }
  end

  after(:all) do
    VCAP::CloudController::Models::ServiceInstance.gateway_client_class = @original_klass
  end

  let(:gateway_url) { "http://horsemeat.com" }
  let(:service) { VCAP::CloudController::Models::Service.make(:url => gateway_url) }
  let(:service_instance) do
    VCAP::CloudController::Models::ServiceInstance.make(
      :service_plan => VCAP::CloudController::Models::ServicePlan.make(:service => service),
    )
  end
  let(:developer) { make_developer_for_space(service_instance.space) }
  let(:req) { Yajl::Encoder.encode("service_instance_guid" => service_instance.guid) }

  before :each do
    stub_request(:post, "#{gateway_url}/gateway/v1/configurations").to_return(
      :status => 200,
      body: VCAP::Services::Api::GatewayHandleResponse.new(
        :service_id => "svcid",
        :configuration => "",
        :credentials => "",
      ).encode,
    )
  end

  it 'creates an empty snapshot', type: :api do
    # FIXME: Yuuuuck
    VCAP::CloudController::SecurityContext.stub(:current_user_email => "dummy@example.com")
    service_instance.service_plan.service.update(:url => gateway_url)
    snapshot_id = rand(10<<32)
    snapshot_state = 'EMPTY'
    stub_request(:post, %r(#{gateway_url}/.*)).
      to_return(
        status: 200,
        body: {snapshot: {id: snapshot_id, state: snapshot_state}}.to_json
      )
    post "/v2/snapshots", req, headers_for(developer)
    last_response.status.should eq 201
    a_request(:post, "#{gateway_url}/gateway/v2/configurations/#{service_instance.gateway_name}/snapshots").should have_been_made
  end

end
