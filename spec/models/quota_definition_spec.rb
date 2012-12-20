# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
  describe VCAP::CloudController::Models::QuotaDefinition do
    it_behaves_like "a CloudController model", {
      :required_attributes => [:name, :non_basic_services_allowed,
                               :total_services, :free_memory_limit,
                               :paid_memory_limit],
      :unique_attributes   => [:name]
    }

    describe ".populate_from_config" do
      it "should load quota definitions" do
        reset_database

        # see config/cloud_controller.yml
        Models::QuotaDefinition.populate_from_config(config)

        Models::QuotaDefinition.count.should == 3
        runaway = Models::QuotaDefinition[:name => "runaway"]
        runaway.non_basic_services_allowed.should == true
        runaway.total_services.should == 500
        runaway.free_memory_limit.should == 1024
        runaway.paid_memory_limit.should == 204800
      end
    end

    describe ".default" do
      it "should return the default quota" do
        Models::QuotaDefinition.default.name.should == "free"
      end
    end
  end
end
