# Copyright (c) 2009-2011 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)
require File.expand_path("../../resource_pool/spec_helper", __FILE__)

module VCAP::CloudController
  describe VCAP::CloudController::ResourceMatch do
    include_context "resource pool", FilesystemPool

    before(:all) do
      FilesystemPool.add_directory(@tmpdir)
    end

    describe "POST /resources" do
      it "should return an empty list when no resources match" do
        resource_match_request(:post, "/resources", [], [@dummy_descriptor])
      end

      it "should return a resource that matches" do
        resource_match_request(:post, "/resources", [@descriptors.first], [@dummy_descriptor])
      end

      it "should return many resources that match" do
        resource_match_request(:post, "/resources", @descriptors, [@dummy_descriptor])
      end
    end
  end
end
