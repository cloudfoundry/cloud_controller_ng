# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
  describe VCAP::CloudController::ResourcePool do
    include_context "resource pool"

    describe "#match_resources" do
      before(:all) do
        ResourcePool.add_directory(@tmpdir)
      end

      it "should return an empty list when no resources match" do
        res = ResourcePool.match_resources([@dummy_descriptor])
        res.should == []
      end

      it "should return a resource that matches" do
        res = ResourcePool.match_resources([@descriptors.first, @dummy_descriptor])
        res.should == [@descriptors.first]
      end

      it "should return many resources that match" do
        res = ResourcePool.match_resources(@descriptors + [@dummy_descriptor])
        res.should == @descriptors
      end
    end

    describe "#resource_sizes" do
      it "should return resources with sizes" do
        without_sizes = @descriptors.map do |d|
          { "sha1" => d["sha1"] }
        end

        res = ResourcePool.resource_sizes(without_sizes)
        res.should == @descriptors
      end
    end

    describe "#add_path" do
      it "should walk the fs tree and add only allowable files" do
        ResourcePool.should_receive(:add_path).exactly(@total_allowed_files).times
        ResourcePool.add_directory(@tmpdir)
      end
    end
  end
end
