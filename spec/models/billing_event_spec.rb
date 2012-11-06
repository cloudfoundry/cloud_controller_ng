# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
  describe VCAP::CloudController::Models::BillingEvent do
    before(:all) do
      Models::BillingEvent.delete
      @org_event = Models::OrganizationStartEvent.make
      @app_start_event = Models::AppStartEvent.make
      @app_stop_event = Models::AppStopEvent.make
      @service_create_event = Models::ServiceCreateEvent.make
      @service_delete_event = Models::ServiceDeleteEvent.make
    end

    describe "all" do
      it "should return an array of all events" do
        Models::BillingEvent.all.should == [
          @org_event,
          @app_start_event,
          @app_stop_event,
          @service_create_event,
          @service_delete_event,
        ]
      end

      it "should return events with the correct event_type strings" do
        Models::BillingEvent.map(&:event_type).should == [
          "organization_billing_start",
          "app_start",
          "app_stop",
          "service_create",
          "service_delete",
        ]
      end
    end
  end
end
