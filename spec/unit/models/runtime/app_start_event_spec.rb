require "spec_helper"

module VCAP::CloudController
  describe VCAP::CloudController::AppStartEvent, type: :model do
    before do
      TestConfig.override({ :billing_event_writing_enabled => true })
    end

    it { is_expected.to have_timestamp_columns }

    describe "Validations" do
      it { is_expected.to validate_presence :timestamp }
      it { is_expected.to validate_presence :organization_guid }
      it { is_expected.to validate_presence :organization_name }
      it { is_expected.to validate_presence :space_guid }
      it { is_expected.to validate_presence :space_name }
      it { is_expected.to validate_presence :app_guid }
      it { is_expected.to validate_presence :app_name }
      it { is_expected.to validate_presence :app_run_id }
      it { is_expected.to validate_presence :app_plan_name }
      it { is_expected.to validate_presence :app_memory }
      it { is_expected.to validate_presence :app_instance_count }
      it { is_expected.to validate_uniqueness :app_run_id}
    end

    describe "Serialization" do
      it { is_expected.to export_attributes :timestamp, :event_type, :organization_guid, :organization_name, :space_guid, :space_name,
                                    :app_guid, :app_name, :app_run_id, :app_plan_name, :app_memory, :app_instance_count }
      it { is_expected.to import_attributes }
    end

    describe "create_from_app" do
      context "on an org without billing enabled" do
        it "should do nothing" do
          expect(AppStartEvent).not_to receive(:create)
          app = AppFactory.make
          app.space.organization.billing_enabled = false
          app.space.organization.save(:validate => false)
          AppStartEvent.create_from_app(app)
        end
      end

      context "on an org with billing enabled" do
        it "should create an app start event" do
          expect(AppStartEvent).to receive(:create)
          app = AppFactory.make
          app.space.organization.billing_enabled = true
          app.space.organization.save(:validate => false)
          AppStartEvent.create_from_app(app)
        end
      end
    end
  end
end
