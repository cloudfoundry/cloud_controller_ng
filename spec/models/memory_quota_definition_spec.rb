# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
  describe VCAP::CloudController::Models::MemoryQuotaDefinition do
    it_behaves_like "a CloudController model", {
      :required_attributes => [:name, :free_limit, :paid_limit],
      :unique_attributes   => [:name],
    }

    describe ".populate_from_config" do
      it "should load quota definitions" do
        reset_database

        # see config/cloud_controller.yml
        Models::MemoryQuotaDefinition.populate_from_config(config)

        Models::MemoryQuotaDefinition.count.should == 3
        runaway = Models::MemoryQuotaDefinition[:name => "runaway"]
        runaway.free_limit = 1024
        runaway.paid_limit = 2048
      end
    end
  end
end
