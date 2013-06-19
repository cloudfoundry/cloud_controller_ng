# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
  describe VCAP::CloudController::ResourcePool do
    include_context "resource pool"

    describe "#match_resources" do
      before(:all) do
        @resource_pool.add_directory(@tmpdir)
      end

      it "should return an empty list when no resources match" do
        res = @resource_pool.match_resources([@dummy_descriptor])
        res.should == []
      end

      it "should return a resource that matches" do
        res = @resource_pool.match_resources([@descriptors.first, @dummy_descriptor])
        res.should == [@descriptors.first]
      end

      it "should return many resources that match" do
        res = @resource_pool.match_resources(@descriptors + [@dummy_descriptor])
        res.should == @descriptors
      end
    end

    describe "#resource_sizes" do
      it "should return resources with sizes" do
        without_sizes = @descriptors.map do |d|
          { "sha1" => d["sha1"] }
        end

        res = @resource_pool.resource_sizes(without_sizes)
        res.should == @descriptors
      end
    end

    describe "#add_path" do
      it "should walk the fs tree and add only allowable files" do
        @resource_pool.should_receive(:add_path).exactly(@total_allowed_files).times
        @resource_pool.add_directory(@tmpdir)
      end
    end

    describe "#size_allowed?" do
      before do
        @minimum_size = 5
        @maximum_size = 7
        @resource_pool.minimum_size = @minimum_size
        @resource_pool.maximum_size = @maximum_size
      end

      it "should return true for a size between min and max size" do
        @resource_pool.send(:size_allowed?, @minimum_size + 1).should be_true
      end

      it "should return false for a size < min size" do
        @resource_pool.send(:size_allowed?, @minimum_size - 1).should be_false
      end

      it "should return false for a size > max size" do
        @resource_pool.send(:size_allowed?, @maximum_size + 1).should be_false
      end

      it "should return false for a nil size" do
        @resource_pool.send(:size_allowed?, nil).should be_false
      end
    end

    describe "#copy" do
      let(:fake_io) { double :dest }
      let(:files) { double :files }
      let(:resource_dir) { double :resource_dir, :files => files }

      let(:descriptor) do
        { "sha1" => "deadbeef" }
      end

      before do
        @resource_pool.stub(:resource_known?).and_return(true)
        @resource_pool.stub(:resource_dir).and_return(resource_dir)
        files.stub(:get)
        File.stub(:open).and_yield(fake_io)
      end

      it "creates the path to the destination" do
        FileUtils.should_receive(:mkdir_p).with("some")
        @resource_pool.copy(descriptor, "some/destination")
      end

      it "streams the resource to the destination" do
        fake_io.should_receive(:write).with("chunk one")
        fake_io.should_receive(:write).with("chunk two")

        files.should_receive(:get).with("de/ad/deadbeef").
          and_yield("chunk one", 9, 18).
          and_yield("chunk two", 0, 18)

        @resource_pool.copy(descriptor, "some/destination")
      end
    end
  end
end
