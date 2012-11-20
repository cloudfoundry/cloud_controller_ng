# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
  describe VCAP::CloudController::Models::Runtime do
    it_behaves_like "a CloudController model", {
      :required_attributes        => [:name, :description],
      :unique_attributes          => :name,
      :stripped_string_attributes => :name,
      :one_to_zero_or_more => {
        :apps => lambda { |service_binding| Models::App.make }
      }
    }

    describe ".populate_from_file" do
      it "should load runtimes" do
        yml = File.expand_path("../../../config/runtimes.yml", __FILE__)
        reset_database
        Models::Runtime.populate_from_file(yml)
        java = Models::Runtime.find(:name => "java")
        java.should be_valid
      end
    end

    describe "#internal_info" do
      it "should serialize and deserialize hashes" do
        yml = File.expand_path("../../../config/runtimes.yml", __FILE__)
        Models::Runtime.populate_from_file(yml)
        java = Models::Runtime.find(:name => "java")
        java.internal_info.should_not be_nil
        java.internal_info["version"].should == "1.6"
      end
    end
  end
end
