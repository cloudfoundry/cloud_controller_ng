require "spec_helper"

module VCAP::CloudController
  describe VCAP::CloudController::AppStartEvent, type: :model do
    before do
      TestConfig.override({ :billing_event_writing_enabled => true })
    end

    it_behaves_like "a CloudController model", {
      :skip_database_constraints => true
    }

    it { should have_timestamp_columns }

    describe "Validations" do
      it { should validate_presence :timestamp }
      it { should validate_presence :organization_guid }
      it { should validate_presence :organization_name }
      it { should validate_presence :space_guid }
      it { should validate_presence :space_name }
      it { should validate_presence :app_guid }
      it { should validate_presence :app_name }
      it { should validate_presence :app_run_id }
      it { should validate_presence :app_plan_name }
      it { should validate_presence :app_memory }
      it { should validate_presence :app_instance_count }
      it { should validate_uniqueness :app_run_id}
    end

    describe "Serialization" do
      it { should export_attributes :timestamp, :event_type, :organization_guid, :organization_name, :space_guid, :space_name,
                                    :app_guid, :app_name, :app_run_id, :app_plan_name, :app_memory, :app_instance_count }
      it { should import_attributes }
    end

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
