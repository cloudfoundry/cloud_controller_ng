# Copyright (c) 2009-2012 VMware, Inc.

require "spec_helper"

module VCAP::CloudController
  module Models
    describe VCAP::CloudController::ServiceInstance do
      describe "#service_gateway_client" do
        it "uses the correct url and credential and timeout" do
          gw_client = double(:client)

          service = Service.make(
            :url => "http://example.com:56789",
            :timeout => 20,
          )
          token = ServiceAuthToken.create(
            :service => service,
            :token => "blah",
          )
          service_plan = ServicePlan.make(:service => service)
          VCAP::Services::Api::ServiceGatewayClient.should_receive(:new).with(
            "http://example.com:56789",
            "blah",
            20,
            instance_of(Hash),
          ).and_return(gw_client)

          # just raise an error so that we don't have to mock out the response,
          # we only care about the arg checks in the previous should_receive
          gw_client.should_receive(:provision).and_raise("fail")
          expect {
            ServiceInstance.make(:service_plan => service_plan)
          }.to raise_error
        end
      end
    end
  end
end
