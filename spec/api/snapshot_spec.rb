# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

describe VCAP::CloudController::Snapshots do
  describe "POST", "/v2/snapshots" do
    let(:service_instance) do
      VCAP::CloudController::Models::ServiceInstance.make
    end
   let(:payload) { Yajl::Encoder.encode(:service_instance_guid => service_instance.guid) }
    before do
      post "/v2/snapshots", payload, {}
    end
    it "requires authentication" do
      last_response.status.should == 401
    end

    context "once authenticated" do
      let(:developer) {make_developer_for_space(service_instance.space)}
      let(:success_response) { {"snapshot" => {"id" => "snapshot-id", "other" => "data", "state" => "empty"}} }

      it "invokes create_snapshot on the corresponding service instance" do
        inst = double("a service instance")
        VCAP::CloudController::Models::ServiceInstance.should_receive(:find).with(:guid => service_instance.guid).and_return(inst)
        inst.should_receive(:create_snapshot).and_return("")
        post "/v2/snapshots", payload, headers_for(developer)
      end

      context "when the gateway successfully creates the snapshot" do
        before do
          VCAP::CloudController::Models::ServiceInstance.any_instance.stub(:create_snapshot).and_return(success_response)
        end

        it "returns the details of the new snapshot" do
          post "/v2/snapshots", payload, headers_for(developer)
          last_response.status.should < 300
          snapguid = "#{service_instance.guid}:snapshot-id"
          decoded_response['metadata'].should == {"guid" => snapguid, "url" => "/v2/snapshots/#{snapguid}"}
          decoded_response['entity'].should == {"guid" => snapguid, "state" => "empty"}
        end
      end
    end
  end
end
