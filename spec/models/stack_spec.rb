# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
  describe VCAP::CloudController::Models::Stack do
    it_behaves_like "a CloudController model", {
      :required_attributes        => [:name, :description],
      :unique_attributes          => :name,
      :stripped_string_attributes => :name,
    }

    describe ".populate_from_directory" do
      before { reset_database }

      it "loads stacks" do
        dir = File.expand_path("../../fixtures/config/stacks", __FILE__)
        Models::Stack.populate_from_directory(dir)
        cider = Models::Stack.find(:name => "cider")
        cider.should be_valid
      end

      it "populates descriptions about loaded stacks" do
        dir = File.expand_path("../../fixtures/config/stacks", __FILE__)
        Models::Stack.populate_from_directory(dir)
        cider = Models::Stack.find(:name => "cider")
        cider.description.should == "cider-description"
      end
    end
  end
end
