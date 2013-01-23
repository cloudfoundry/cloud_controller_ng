# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
  describe VCAP::CloudController::Models::Framework do
    it_behaves_like "a CloudController model", {
      :required_attributes        => [:name, :description, :internal_info],
      :unique_attributes          => :name,
      :stripped_string_attributes => :name,
      :one_to_zero_or_more => {
        :apps => lambda { |service_binding| Models::App.make }
      }
    }

    describe ".populate_from_directory" do
      it "should load frameworks" do
        dir = File.expand_path("../../../config/frameworks", __FILE__)
        reset_database
        Models::Framework.populate_from_directory(dir)
        sinatra = Models::Framework.find(:name => "sinatra")
        sinatra.should be_valid
      end
    end

    describe "#internal_info" do
      it "should serialize and deserialize hashes" do
        dir = File.expand_path("../../../config/frameworks", __FILE__)
        Models::Framework.populate_from_directory(dir)
        sinatra = Models::Framework.find(:name => "sinatra")
        sinatra.internal_info.should_not be_nil
        sinatra.internal_info["runtimes"].size.should == 3
      end
    end
  end
end
