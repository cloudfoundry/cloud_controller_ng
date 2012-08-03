# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

describe VCAP::CloudController::FilesystemPool do
  include_context "resource pool"

  describe "#match_resources" do
    before(:all) do
      FilesystemPool.add_directory(tmpdir)
    end

    it "should return an empty list when no resources match" do
      res = FilesystemPool.match_resources([dummy_descriptor])
      res.should == []
    end

    it "should return a resource that matches" do
      res = FilesystemPool.match_resources([@descriptors.first, dummy_descriptor])
      res.should == [@descriptors.first]
    end

    it "should return many resources that match" do
      res = FilesystemPool.match_resources(@descriptors + [dummy_descriptor])
      res.should == @descriptors
    end
  end

  describe "#resource_sizes" do
    it "should return resources with sizes" do
      without_sizes = @descriptors.map do |d|
        { "sha1" => d["sha1"] }
      end

      res = FilesystemPool.resource_sizes(without_sizes)
      res.should == @descriptors
    end
  end
end
