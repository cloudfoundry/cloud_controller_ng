require "spec_helper"

module VCAP::CloudController
  describe VCAP::CloudController::AppStartEvent, type: :model do
    before do
      config_override({ :billing_event_writing_enabled => true })
    end

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
      :unique_attributes => [
        :app_run_id
      ],
      :disable_examples => :deserialization,
      :skip_database_constraints => true
    }

    describe "create_from_app" do
      context "on an org without billing enabled" do
        it "should do nothing" do
          AppStartEvent.should_not_receive(:create)
          app = AppFactory.make
          app.space.organization.billing_enabled = false
          app.space.organization.save(:validate => false)
          AppStartEvent.create_from_app(app)
        end
      end

      context "on an org with billing enabled" do
        it "should create an app start event" do
          AppStartEvent.should_receive(:create)
          app = AppFactory.make
          app.space.organization.billing_enabled = true
          app.space.organization.save(:validate => false)
          AppStartEvent.create_from_app(app)
        end
      end
    end
  end
end
