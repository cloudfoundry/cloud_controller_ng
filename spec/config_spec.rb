# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
  describe Config do

    describe ".from_file" do
      it "raises if the file does not exist" do
        expect {
          Config.from_file("nonexistent.yml")
        }.to raise_error(Errno::ENOENT, /No such file or directory - nonexistent.yml/)
      end

      it "adds default runtime file path" do
        config = Config.from_file(File.expand_path("../fixtures/config/minimal_config.yml", __FILE__))
        config[:runtimes_file].should == File.join(Config.config_dir, "runtimes.yml")
      end

      it "adds default frameworks directory path" do
        config = Config.from_file(File.expand_path("../fixtures/config/minimal_config.yml", __FILE__))
        config[:directories][:staging_manifests].should == File.join(Config.config_dir, "frameworks")
      end

      it "adds default stack file path" do
        config = Config.from_file(File.expand_path("../fixtures/config/minimal_config.yml", __FILE__))
        config[:stacks_file].should == File.join(Config.config_dir, "stacks.yml")
      end
    end
  end
end
