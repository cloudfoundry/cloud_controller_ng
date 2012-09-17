# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
  describe VCAP::CloudController::ResourcePool do
    include_context "resource pool"

    describe "#match_resources" do
      it "should raise NotImplementedError" do
        lambda {
          ResourcePool.match_resources([dummy_descriptor])
        }.should raise_error(NotImplementedError)
      end
    end

    describe "#resource_known?" do
      it "should raise NotImplementedError" do
        lambda {
          ResourcePool.resource_known?(dummy_descriptor)
        }.should raise_error(NotImplementedError)
      end
    end

    describe "#add_path" do
      it "should raise NotImplementedError" do
        lambda {
          ResourcePool.add_path(tmpdir)
        }.should raise_error(NotImplementedError)
      end
    end

    describe "#add_path" do
      it "should walk the fs tree and add only allowable files" do
        ResourcePool.should_receive(:add_path).exactly(total_allowed_files).times
        ResourcePool.add_directory(tmpdir)
      end
    end
  end
end
