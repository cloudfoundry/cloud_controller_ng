require "spec_helper"

module VCAP::CloudController
  describe VCAP::CloudController::BillingEvent, type: :model do
    before do
      BillingEvent.dataset.destroy
    end

    it { is_expected.to have_timestamp_columns }

    describe ".create" do
      let(:values) { {
          timestamp: Time.now,
          organization_guid: "abc",
          organization_name: "def",
      } }

      context "when billing event writing is enabled" do
        before do
          TestConfig.override({ :billing_event_writing_enabled => true })
        end

        it "adds a new row to the database table" do
          expect { BillingEvent.create(values) }.to change { BillingEvent.count }.from(0).to(1)
        end
      end

      context "when billing event writing is disabled" do
        before do
          TestConfig.override({ :billing_event_writing_enabled => false })
        end

        it "does not add a new row to the database table" do
          expect { BillingEvent.create(values) }.not_to change { BillingEvent.count }
        end
      end
    end

    describe "all" do
      before do
        @org_event = OrganizationStartEvent.make
        @app_start_event = AppStartEvent.make
        @app_stop_event = AppStopEvent.make
        @service_create_event = ServiceCreateEvent.make
        @service_delete_event = ServiceDeleteEvent.make
      end

      it "should return an array of all events" do
        expect(BillingEvent.all).to eq([
          @org_event,
          @app_start_event,
          @app_stop_event,
          @service_create_event,
          @service_delete_event,
        ])
      end

      it "should return events with the correct event_type strings" do
        expect(BillingEvent.map(&:event_type)).to eq([
          "organization_billing_start",
          "app_start",
          "app_stop",
          "service_create",
          "service_delete",
        ])
      end
    end

    describe "old and new data coexisting if the class name is changed" do
      shared_examples_for "an event which works with both single table inheritance keys" do |klass, old_kind_column_value|
        describe klass.to_s do
          it "can handle the old format of the single table inheritance kind column" do
            old_format_event = klass.make
            old_format_event.kind = old_kind_column_value
            old_format_event.save
            klass.make kind: klass.to_s

            billing_event_classes = BillingEvent.all.map(&:class)
            expect(billing_event_classes).to eq([klass, klass])
          end
        end
      end

      it_behaves_like "an event which works with both single table inheritance keys", OrganizationStartEvent, "VCAP::CloudController::Models::OrganizationStartEvent"
      it_behaves_like "an event which works with both single table inheritance keys", AppStartEvent, "VCAP::CloudController::Models::AppStartEvent"
      it_behaves_like "an event which works with both single table inheritance keys", AppStopEvent, "VCAP::CloudController::Models::AppStopEvent"
      it_behaves_like "an event which works with both single table inheritance keys", ServiceCreateEvent, "VCAP::CloudController::Models::ServiceCreateEvent"
      it_behaves_like "an event which works with both single table inheritance keys", ServiceDeleteEvent, "VCAP::CloudController::Models::ServiceDeleteEvent"
    end
  end
end
