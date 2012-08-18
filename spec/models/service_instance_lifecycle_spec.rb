# Copyright (c) 2009-2012 VMware, Inc.

require "spec_helper"

module VCAP::CloudController::Models
  describe ServiceInstance do
    describe "#service_gateway_client" do
      it "uses the correct url and credential and timeout" do
        service = Service.make(
          :url => "http://example.com:56789",
          :timeout => 20,
        )
        token = ServiceAuthToken.create(
          :service => service,
          :token => "blah",
        )
        service_plan = ServicePlan.make(:service => service)
        service_instance = ServiceInstance.make(:service_plan => service_plan)
        VCAP::Services::Api::ServiceGatewayClient.should_receive(:new).with(
          "http://example.com:56789",
          "blah",
          20,
          instance_of(Hash),
        )
        service_instance.service_gateway_client
      end
    end
  end
end
