# Copyright (c) 2011-2013 Uhuru Software, Inc.

require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
  describe VCAP::CloudController::Models::SupportedBuildpack do
    it_behaves_like "a CloudController model", {
      :required_attributes        => [:name, :description, :buildpack],
      :unique_attributes          => :name,
      :stripped_string_attributes => :name
    }

    describe ".populate_from_file" do
      it "should load supported buildpacks" do
        yml = File.expand_path("../../../config/supported_buildpacks.yml", __FILE__)
        reset_database
        Models::SupportedBuildpack.populate_from_file(yml)
        ruby = Models::SupportedBuildpack.find(:name => "ruby")
        ruby.should be_valid
      end
    end

  end
end
