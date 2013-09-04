require "spec_helper"

module VCAP::CloudController
  describe VCAP::CloudController::BillingEvent, type: :model do
    before(:all) do
      BillingEvent.dataset.destroy
      @org_event = OrganizationStartEvent.make
      @app_start_event = AppStartEvent.make
      @app_stop_event = AppStopEvent.make
      @service_create_event = ServiceCreateEvent.make
      @service_delete_event = ServiceDeleteEvent.make
    end

    describe "all" do
      it "should return an array of all events" do
        BillingEvent.all.should == [
          @org_event,
          @app_start_event,
          @app_stop_event,
          @service_create_event,
          @service_delete_event,
        ]
      end

      it "should return events with the correct event_type strings" do
        BillingEvent.map(&:event_type).should == [
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
