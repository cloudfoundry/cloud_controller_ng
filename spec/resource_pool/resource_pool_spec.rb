# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

describe VCAP::CloudController::ResourcePool do
  NUM_DIRS = 3
  NUM_ALLOWED_FILES = 7
  MAX_FILE_SIZE = 1098 # this is arbitrary

  before(:all) do
    cfg = { :resource_pool => { :maximum_size => MAX_FILE_SIZE }}
    ResourcePool.configure(cfg)

    @tmpdir = Dir.mktmpdir

    # make 3 dirs each with 7 unique files
    NUM_DIRS.times do
      dirname = SecureRandom.uuid
      Dir.mkdir("#{@tmpdir}/#{dirname}")
      NUM_ALLOWED_FILES.times do
        filename = SecureRandom.uuid
        File.open("#{@tmpdir}/#{dirname}/#{filename}", "w") do |f|
          contents = SecureRandom.uuid
          f.write contents
        end

        File.open("#{@tmpdir}/#{dirname}/#{filename}-not-allowed", "w") do |f|
          f.write "A" * MAX_FILE_SIZE
        end
      end
    end
  end

  after(:all) do
    FileUtils.rm_rf(@tmpdir)
  end

  describe "#match_resources" do
    it "should raise NotImplementedError" do
      lambda {
        ResourcePool.match_resources(["abc"])
      }.should raise_error(NotImplementedError)
    end
  end

  describe "#resource_known?" do
    it "should raise NotImplementedError" do
      lambda {
        ResourcePool.resource_known?("abc")
      }.should raise_error(NotImplementedError)
    end
  end

  describe "#add_path" do
    it "should raise NotImplementedError" do
      lambda {
        ResourcePool.add_path(@tmpdir)
      }.should raise_error(NotImplementedError)
    end
  end

  describe "#add_path" do
    it "should walk the fs tree and add only allowable files" do
      ResourcePool.should_receive(:add_path).exactly(NUM_DIRS * NUM_ALLOWED_FILES).times
      ResourcePool.add_directory(@tmpdir)
    end
  end
end
