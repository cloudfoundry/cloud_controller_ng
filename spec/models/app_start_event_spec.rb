# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
  describe VCAP::CloudController::Models::AppStartEvent do
    it_behaves_like "a CloudController model", {
      :required_attributes => [
        :timestamp,
        :organization_guid,
        :organization_name,
        :space_guid,
        :space_name,
        :app_guid,
        :app_name,
        :app_run_id,
        :app_plan_name,
        :app_memory,
        :app_instance_count,
      ],
      :db_required_attributes => [
        :timestamp,
        :organization_guid,
        :organization_name,
      ],
      :disable_examples => :deserialization
    }

    describe "create_from_app" do
      context "on an org without billing enabled" do
        it "should do nothing" do
          Models::AppStartEvent.should_not_receive(:create)
          app = Models::App.make
          app.space.organization.billing_enabled = false
          app.space.organization.save(:validate => false)
          Models::AppStartEvent.create_from_app(app)
        end
      end

      context "on an org with billing enabled" do
        it "should create an app start event" do
          Models::AppStartEvent.should_receive(:create)
          app = Models::App.make
          app.space.organization.billing_enabled = true
          app.space.organization.save(:validate => false)
          Models::AppStartEvent.create_from_app(app)
        end
      end
    end
  end
end
