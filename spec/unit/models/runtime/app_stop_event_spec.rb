require "spec_helper"

module VCAP::CloudController
  describe VCAP::CloudController::AppStopEvent, type: :model do
    before do
      TestConfig.override({ :billing_event_writing_enabled => true })
    end

    it_behaves_like "a CloudController model", {
      :disable_examples => :deserialization,
      :skip_database_constraints => true
    }

    describe "Validations" do
      it { should validate_presence :timestamp }
      it { should validate_presence :organization_guid }
      it { should validate_presence :organization_name }
      it { should validate_presence :space_guid }
      it { should validate_presence :space_name }
      it { should validate_presence :app_guid }
      it { should validate_presence :app_name }
      it { should validate_uniqueness :app_run_id }
    end

    describe "create_from_app" do
      context "on an org without billing enabled" do
        it "should do nothing" do
          AppStopEvent.should_not_receive(:create)
          app = AppFactory.make
          app.space.organization.billing_enabled = false
          app.space.organization.save(:validate => false)
          AppStopEvent.create_from_app(app)
        end
      end

      context "on an org with billing enabled" do
        let(:app) { AppFactory.make }

        before do
          app.space.organization.billing_enabled = true
          app.space.organization.save(:validate => false)
        end

        it "should create an app stop event using the run id from the most recently created start event" do
          Timecop.freeze do
            newest_by_time = AppStartEvent.create_from_app(app)

            newest_by_sequence = AppStartEvent.create_from_app(app)
            newest_by_sequence.timestamp = Time.now - 3600
            newest_by_sequence.save

            stop_event = AppStopEvent.create_from_app(app)
            stop_event.app_run_id.should == newest_by_sequence.app_run_id
          end
        end

        context "when a corresponding AppStartEvent is not found" do
          it "does NOT raise an exception" do
            expect {
              AppStopEvent.create_from_app(app)
            }.to_not raise_error
          end

          it "does not create a StopEvent" do
            expect {
              AppStopEvent.create_from_app(app)
            }.to_not change { AppStopEvent.count }
          end
        end
      end
    end
  end
end
