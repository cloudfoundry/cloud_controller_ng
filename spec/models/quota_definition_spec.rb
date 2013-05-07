# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
  describe VCAP::CloudController::Models::QuotaDefinition do
    let(:quota_definition) { Models::QuotaDefinition.make }

    it_behaves_like "a CloudController model", {
      :required_attributes => [:name, :non_basic_services_allowed,
                               :total_services, :memory_limit],
      :unique_attributes   => [:name]
    }

    describe ".populate_from_config" do
      it "should load quota definitions" do
        reset_database

        # see config/cloud_controller.yml
        Models::QuotaDefinition.populate_from_config(config)

        Models::QuotaDefinition.count.should == 3
        paid = Models::QuotaDefinition[:name => "paid"]
        paid.non_basic_services_allowed.should == true
        paid.total_services.should == 500
        paid.memory_limit.should == 204800
      end
    end

    describe ".default" do
      it "should return the default quota" do
        Models::QuotaDefinition.default.name.should == "free"
      end
    end

    describe "#destroy" do
      it "nullifies the organization quota definition" do
        org = Models::Organization.make(:quota_definition => quota_definition)
        expect { quota_definition.destroy }.to change { Models::Organization.where(:id => org.id).count }.by(-1)
      end
    end
  end
end
