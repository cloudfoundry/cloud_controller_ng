# Copyright (c) 2009-2011 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)
require File.expand_path("../../resource_pool/spec_helper", __FILE__)

module VCAP::CloudController
  describe VCAP::CloudController::ResourceMatch do
    include_context "resource pool", FilesystemPool

    before(:all) do
      FilesystemPool.add_directory(tmpdir)
    end

    describe "PUT /v2/resource_match" do
      it "should return an empty list when no resources match" do
        resource_match_request(:put, "/v2/resource_match", [], [dummy_descriptor])
      end

      it "should return a resource that matches" do
        resource_match_request(:put, "/v2/resource_match", [@descriptors.first], [dummy_descriptor])
      end

      it "should return many resources that match" do
        resource_match_request(:put, "/v2/resource_match", @descriptors, [dummy_descriptor])
      end
    end
  end
end
