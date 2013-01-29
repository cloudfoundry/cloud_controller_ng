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

    describe "#size_allowed?" do
      before do
        @minimum_size = 5
        @maximum_size = 7
        ResourcePool.minimum_size = @minimum_size
        ResourcePool.maximum_size = @maximum_size
      end

      it "should return true for a size between min and max size" do
        ResourcePool.send(:size_allowed?, @minimum_size + 1).should be_true
      end

      it "should return false for a size < min size" do
        ResourcePool.send(:size_allowed?, @minimum_size - 1).should be_false
      end

      it "should return false for a size > max size" do
        ResourcePool.send(:size_allowed?, @maximum_size + 1).should be_false
      end

      it "should return false for a nil size" do
        ResourcePool.send(:size_allowed?, nil).should be_false
      end
    end
  end
end
