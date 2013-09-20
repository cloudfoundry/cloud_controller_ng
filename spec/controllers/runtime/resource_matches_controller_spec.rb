require "spec_helper"

module VCAP::CloudController
  describe VCAP::CloudController::ResourceMatchesController, type: :controller do
    include_context "resource pool"

    before do
      @resource_pool.add_directory(@tmpdir)
    end

    describe "PUT /v2/resource_match" do
      it "should return an empty list when no resources match" do
        resource_match_request(:put, "/v2/resource_match", [], [@dummy_descriptor])
      end

      it "should return a resource that matches" do
        resource_match_request(:put, "/v2/resource_match", [@descriptors.first], [@dummy_descriptor])
      end

      it "should return many resources that match" do
        resource_match_request(:put, "/v2/resource_match", @descriptors, [@dummy_descriptor])
      end
    end
  end
end
